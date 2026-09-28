# Plan: Movement + Horde Polish

## 1. Existing implementation assessment

The codebase currently has a functional combat vertical slice:
- Client: First-person camera, animatable viewmodel with character arms, custom `PistolIdle` animation (`rbxassetid://105188840604362`), semi-auto pistol firing, auto-reload, and ammo display.
- Server: Server-authoritative raycasting, damage (25 dmg per body hit), zombie AI pursuit, and horde spawner.
- Zombie: Cloned R15 rig from `ReplicatedStorage.Assets.Zombie` playing `Idle`, `Walk`/`Run`, and `DeathAnimation`.

However, testing revealed specific mechanical and visual issues:
1. **Zombie Death Standing Glitch**: When a zombie reaches 0 HP, `DeathAnimation` plays once, but when the unlooped animation track reaches its end, Roblox's Animator stops applying it. For the remaining ~1.8s until `Destroy()`, the rig snaps back to an upright standing pose.
2. **Zombie Physics Instability & Player Launching**: When the player sprints or runs into a living zombie, collision between the player and the zombie's 15 dynamic R15 parts pushes or launches the zombie across the map.
3. **Player Movement Speed**: Player is locked to default `WalkSpeed = 16` with no sprint mechanic.
4. **Static Viewmodel Movement**: The viewmodel holds `PistolIdle` statically while running, lacking movement feel.
5. **Horde Pressure**: The spawner caps at 15 zombies with slow ramp-up (`InitialMaxAlive = 3`, `DifficultyStepSeconds = 25`).

## 2. Exact death animation final-pose strategy

### The Bug Cause:
Roblox `AnimationTrack`s with `Looped = false` automatically transition to `Stopped` state when they reach their length. Once stopped, the Animator stops writing transforms to the Motor6Ds, causing the joint hierarchy to immediately snap back to default neutral rest pose (standing upright).

### The Fix:
1. Load `DeathAnimation` with `Looped = false` and `Priority = Enum.AnimationPriority.Action4`.
2. In `onDeath()`:
   - Call `deathTrack:Play(0.05)`.
   - Freeze the track at its final frame before it stops:
     ```luau
     task.spawn(function()
         local length = deathTrack.Length
         local start = os.clock()
         while length <= 0 and os.clock() - start < 0.5 do
             task.wait()
             length = deathTrack.Length
         end
         if length > 0.1 then
             task.wait(math.max(0.05, length - 0.08))
             if deathTrack.IsPlaying and model.Parent then
                 deathTrack.TimePosition = math.max(0, length - 0.08)
                 deathTrack:AdjustSpeed(0)
             end
         end
         -- Anchor all parts at the final death pose
         for _, descendant in model:GetDescendants() do
             if descendant:IsA("BasePart") then
                 descendant.Anchored = true
             end
         end
     end)
     ```
3. **Why this works**:
   - `deathTrack:AdjustSpeed(0)` pauses the animation while keeping `IsPlaying = true`. It never reaches the end, so the engine never fires `Stopped` and continues evaluating the final keyframe permanently.
   - Anchoring all BaseParts physically locks the corpse in place on the ground, making it impossible for physics or motor joints to stand back up.
4. **Fallback Safety**:
   - If `deathTrack` fails to load, `pcall` catches the error, and `task.delay(HordeConfig.CorpseCleanupDelay, ...)` still destroys the corpse cleanly after 3 seconds.

## 3. Exact collider hierarchy & physics stability

### The Problem:
Having 15 separate R15 MeshParts colliding with a player creates dozens of friction contact points and torque impulses on Motor6D joints. The client-owned player physics easily overcomes the server-owned zombie joints, launching the zombie into the air.

### The Solution:
1. **Disable Collision on Visual Parts**:
   Set `CanCollide = false` and `CanTouch = false` on all 15 R15 body parts (`Head`, `UpperTorso`, `LowerTorso`, arms, legs, and `HumanoidRootPart`).
   Leave `CanQuery = true` on visual parts so server hitscan raycasts hit the zombie model accurately.
2. **Dedicated Single Collider Part**:
   Create an invisible part named `ZombieCollider` inside the zombie model:
   - Shape: Block
   - Size: `Vector3.new(2.2, 4.8, 1.8)` (encapsulates the torso and legs)
   - CFrame: `root.CFrame`
   - `Transparency = 1`, `CastShadow = false`
   - `CanCollide = true`, `CanTouch = true`, `CanQuery = false` (server raycasts ignore it and hit visual parts)
   - `Massless = false`
   - `CollisionGroup = "Zombies"`
   - `CustomPhysicalProperties`:
     ```luau
     PhysicalProperties.new(
         2.5, -- Density (heavy enough that player cannot push or launch it)
         1.0, -- Friction (prevents sliding)
         0.0, -- Elasticity (zero bounciness; absorbs impact completely)
         100, -- FrictionWeight
         100  -- ElasticityWeight
     )
     ```
   - Welded to `HumanoidRootPart` via a `WeldConstraint`:
     `Part0 = root, Part1 = collider, Parent = collider`.
3. **Immediate Death Passthrough**:
   On death in `onDeath()`:
   ```luau
   local collider = model:FindFirstChild("ZombieCollider")
   if collider and collider:IsA("BasePart") then
       collider.CanCollide = false
   end
   ```
   The player can immediately walk or sprint through the dying corpse without snagging or tripping.

## 4. PhysicsService collision group matrix

Define collision group constants in `src/shared/CollisionGroups.luau`:
```luau
return {
    Default = "Default",
    Players = "Players",
    Zombies = "Zombies",
}
```

### Server Registration (`src/server/init.server.luau`):
On server startup:
```luau
local PhysicsService = game:GetService("PhysicsService")
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local function registerGroups()
    for _, group in { CollisionGroups.Players, CollisionGroups.Zombies } do
        pcall(function()
            PhysicsService:RegisterCollisionGroup(group)
        end)
    end
    PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Default, true)
    PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Zombies, CollisionGroups.Default, true)
    PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Zombies, true)
    PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Zombies, CollisionGroups.Zombies, false)
    PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Players, false)
end
```

### Collision Matrix:
| Group A | Group B | Collidable | Effect |
| :--- | :--- | :---: | :--- |
| `Players` | `Default` | **YES** | Players collide with terrain, baseplate, walls |
| `Zombies` | `Default` | **YES** | Zombies walk on floors and collide with walls |
| `Players` | `Zombies` | **YES** | **Living zombies solidly block the player from walking through them** |
| `Zombies` | `Zombies` | **NO** | **Zombies do NOT push or fling each other; hordes swarm cleanly** |
| `Players` | `Players` | **NO** | Friendly players do not block or shove each other |

### Group Assignment:
- **Zombies**: `ZombieCollider.CollisionGroup = CollisionGroups.Zombies`.
- **Players**: In `PistolServer.luau`, when player spawns, assign `CollisionGroup = CollisionGroups.Players` to all character BaseParts (`HumanoidRootPart`, `UpperTorso`, `LowerTorso`, `Head`).

## 5. Network ownership strategy

- `root:SetNetworkOwner(nil)` is called in `Zombie.spawn()` immediately after parenting the model to `workspace`.
- Ensures the server retains strict authority over the zombie's physics simulation. The client physics engine cannot claim ownership during player contact, preventing client-side pushing or fling glitches.

## 6. Sprint architecture

### Modular Controller (`src/client/SprintController.luau`):
- Centralizes sprinting logic cleanly without cluttering `PistolController` or `init.client`.
- Constants:
  - `NormalWalkSpeed = 16`
  - `SprintWalkSpeed = 24`
- Input Handling:
  - Listens to `UserInputService.InputBegan` for `Enum.KeyCode.LeftShift`.
  - Listens to `UserInputService.InputEnded` for `Enum.KeyCode.LeftShift`.
  - Respects `gameProcessed` (does not sprint if player is typing in chat).
  - Resets to normal speed when `GuiService.MenuOpened` or window focus is lost.
- Lifecycle:
  - Tracks `isSprinting` state.
  - On sprint start: checks living humanoid (`humanoid.Health > 0`); sets `humanoid.WalkSpeed = SprintWalkSpeed`.
  - On sprint end: sets `humanoid.WalkSpeed = NormalWalkSpeed`.
  - On character death/respawn: resets `isSprinting = false`, restores `humanoid.WalkSpeed = NormalWalkSpeed`.
- API:
  - `SprintController.start()`
  - `SprintController.isSprinting(): boolean` (queried by `ViewmodelController` for sprint bob)

## 7. Walk/sprint bob formula and config values

### Configuration (`src/client/ViewmodelConfig.luau`):
```luau
-- Procedural Movement Bobbing
BobSmoothingSpeed = 10,
WalkBobFrequency = 8.5,
WalkBobHorizontal = 0.035,
WalkBobVertical = 0.02,
SprintBobFrequency = 13.0,
SprintBobHorizontal = 0.065,
SprintBobVertical = 0.045,
SprintLowerOffset = CFrame.new(-0.03, -0.12, 0.04) * CFrame.Angles(math.rad(-6), math.rad(4), math.rad(-2)),
```

### Calculation in `ViewmodelController.luau`:
Every frame in `RenderStepped`:
1. Check horizontal movement velocity:
   ```luau
   local root = character and character:FindFirstChild("HumanoidRootPart")
   local humanoid = character and character:FindFirstChildOfClass("Humanoid")
   local velocity = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude else 0
   local isMoving = velocity > 1.5 and humanoid and humanoid.MoveDirection.Magnitude > 0.1
   local isSprinting = isMoving and SprintController.isSprinting()
   ```
2. Accumulate bob cycle:
   - If `isMoving`:
     `bobCycle += dt * (if isSprinting then Config.SprintBobFrequency else Config.WalkBobFrequency)`
   - If not moving:
     `bobCycle` slowly settles to 0.
3. Compute sway and bounce:
   - Horizontal sway: `math.sin(bobCycle) * (if isSprinting then Config.SprintBobHorizontal else Config.WalkBobHorizontal)`
   - Vertical bounce: `math.cos(bobCycle * 2) * (if isSprinting then Config.SprintBobVertical else Config.WalkBobVertical)`
   - Roll tilt: `math.sin(bobCycle) * (if isSprinting then Config.SprintBobHorizontal * 0.4 else Config.WalkBobHorizontal * 0.4)`
   - Target CFrame:
     ```luau
     local bobCFrame = if isMoving then CFrame.new(swayX, bounceY, 0) * CFrame.Angles(0, 0, rollZ) else CFrame.identity
     local sprintCFrame = if isSprinting then Config.SprintLowerOffset else CFrame.identity
     local targetBob = bobCFrame * sprintCFrame
     currentBobOffset = currentBobOffset:Lerp(targetBob, math.clamp(dt * Config.BobSmoothingSpeed, 0, 1))
     ```
4. Layering on Viewmodel:
   ```luau
   viewmodelRoot.CFrame = camera.CFrame * Config.CameraOffset * currentBobOffset * recoilOffset
   ```
   Camera CFrame, server raycast origin (`Head.Position`), and crosshair remain 100% untouched.

## 8. HordeConfig changes

Update `src/shared/HordeConfig.luau`:
```luau
return {
	InitialMaxAlive = 5,
	MaximumMaxAlive = 25,
	InitialSpawnInterval = 3.0,
	MinimumSpawnInterval = 0.7,
	DifficultyStepSeconds = 20,
	MaxAliveIncreasePerStep = 2,
	SpawnIntervalDecreasePerStep = 0.4,
	CorpseCleanupDelay = 3.0,
	MinSpawnRadius = 55,
	MaxSpawnRadius = 95,
	MinPlayerSpawnDistance = 50,
	MinZombieSeparation = 12,
	MaxSpawnAttempts = 10,
	ArenaRadiusLimit = 220,
}
```

### Progression curve:
- **0s**: 5 zombies, 3.0s spawn interval
- **20s**: 7 zombies, 2.6s spawn interval
- **40s**: 9 zombies, 2.2s spawn interval
- **60s**: 11 zombies, 1.8s spawn interval
- **80s**: 13 zombies, 1.4s spawn interval
- **100s**: 15 zombies, 1.0s spawn interval
- **120s**: 17 zombies, 0.7s spawn interval (minimum interval reached)
- **140s**: 19 zombies
- **160s**: 21 zombies
- **180s**: 23 zombies
- **200s (3m 20s)**: 25 zombies (maximum cap reached)

## 9. Files to create

1. `src/shared/CollisionGroups.luau`:
   - Centralizes collision group names (`Default`, `Players`, `Zombies`).
2. `src/client/SprintController.luau`:
   - Manages LeftShift sprint input, `WalkSpeed` transitions, respawn cleanup, and sprint state query.

## 10. Files to modify

1. `src/shared/HordeConfig.luau`:
   - Updated horde density and progression values.
2. `src/server/init.server.luau`:
   - Registers PhysicsService collision groups and defines non-collidable rules for Zombies-vs-Zombies and Players-vs-Players.
3. `src/server/Zombie.luau`:
   - Creates `ZombieCollider` with zero elasticity and solid mass.
   - Disables collisions on visual R15 body parts while keeping `CanQuery = true`.
   - Freezes `DeathAnimation` on its final frame and anchors corpse parts on death.
   - Disables collider collision instantly upon death.
4. `src/server/PistolServer.luau`:
   - Assigns `CollisionGroup = CollisionGroups.Players` to spawned player characters.
5. `src/client/ViewmodelConfig.luau`:
   - Adds procedural walk and sprint bobbing parameters and sprint lowered offset.
6. `src/client/ViewmodelController.luau`:
   - Layers procedural movement and sprint bobbing smoothly atop `CameraOffset`.
7. `src/client/init.client.luau`:
   - Starts `SprintController.start()`.

## 11. Files that remain unchanged

- `default.project.json`
- `src/client/Crosshair.luau`
- `src/client/AmmoGui.luau`
- `src/client/PistolController.luau`
- `src/server/ZombieSpawner.luau` (already uses values from `HordeConfig`)
- `src/shared/PistolConfig.luau`
- `src/shared/ZombieConfig.luau`
- `src/shared/Remotes.luau`
- All binary assets in `assets/`

## 12. Implementation order

1. **Shared Configuration & Groups**:
   - Create `src/shared/CollisionGroups.luau`.
   - Update `src/shared/HordeConfig.luau` with new density targets.
2. **Server Collision Groups & Player Setup**:
   - Update `src/server/init.server.luau` with `PhysicsService` registration.
   - Update `src/server/PistolServer.luau` to set player parts to `Players` collision group.
3. **Zombie Collider & Death Pose**:
   - Update `src/server/Zombie.luau`: build `ZombieCollider`, disable visual part collisions, implement death freeze via `AdjustSpeed(0)` + delayed anchor, and disable collider immediately on death.
4. **Player Sprint**:
   - Create `src/client/SprintController.luau`.
   - Update `src/client/init.client.luau` to call `SprintController.start()`.
5. **Viewmodel Bobbing**:
   - Update `src/client/ViewmodelConfig.luau` with bob parameters.
   - Update `src/client/ViewmodelController.luau` to calculate velocity, query sprint state, and apply smooth bobbing in `RenderStepped`.
6. **Verification**:
   - Check git diff, verify no syntax errors, and test in Roblox Studio.

## 13. Runtime edge cases & mitigations

1. **Player dies while sprinting**:
   - *Risk*: Respawning keeps sprint speed active or glitches `WalkSpeed`.
   - *Mitigation*: `SprintController` listens to `humanoid.Died` and resets `isSprinting = false`. On `CharacterAdded`, `humanoid.WalkSpeed` is strictly set to `NormalWalkSpeed (16)`.
2. **Zombie dies in direct physical contact with player**:
   - *Risk*: Player gets stuck or snagged on the dying corpse.
   - *Mitigation*: In `Zombie.luau`, `onDeath()` immediately sets `ZombieCollider.CanCollide = false`. The player can run right through the collapsing corpse.
3. **Death animation takes time to load from CDN**:
   - *Risk*: `deathTrack.Length` is 0 initially.
   - *Mitigation*: Polling loop waits up to 0.5s for length to populate; if still unknown, a fallback timer anchors parts after 1.0s.
4. **Player presses LeftShift while typing in chat**:
   - *Risk*: Sprint activates unintentionally during chat.
   - *Mitigation*: `UserInputService.InputBegan` checks `if gameProcessed then return end`.
5. **Rapid firing while sprinting**:
   - *Risk*: Viewmodel recoil and sprint bobbing conflict.
   - *Mitigation*: `bobOffset` and `recoilOffset` are multiplicative CFrame offsets (`CameraOffset * currentBobOffset * recoilOffset`). They combine smoothly without jitter.

## 14. Manual Studio verification checklist

1. **Zombie Death Pose**:
   - Shoot and kill a zombie.
   - Verify `DeathAnimation` plays, collapses to the ground, and **freezes on the ground**.
   - Verify the corpse **does NOT stand back up** during the 3 seconds before being destroyed.
2. **Zombie Collision & Blocking**:
   - Walk and run directly into a living zombie.
   - Verify the zombie acts as a solid physical obstacle that stops/blocks the player.
   - Verify the zombie is NOT pushed, slid, launched into the sky, or flung across the baseplate.
3. **Swarm Stability**:
   - Let 5–10 zombies cluster around the player.
   - Verify zombies do not ping-pong, collide violently, or launch each other (Zombies-vs-Zombies non-collidable).
4. **Corpse Passthrough**:
   - Kill a zombie directly in front of you.
   - Verify you can immediately walk or sprint through the falling/dead corpse without obstruction.
5. **Player Sprinting**:
   - Press and hold `LeftShift`: verify character accelerates to `WalkSpeed = 24`.
   - Release `LeftShift`: verify character smoothly decelerates to `WalkSpeed = 16`.
   - Die to a zombie: verify respawn starts cleanly at normal walk speed (16).
6. **Viewmodel Bobbing**:
   - Stand still: viewmodel holds authored `PistolIdle` pose.
   - Walk: viewmodel demonstrates subtle vertical bounce and horizontal sway.
   - Sprint: viewmodel demonstrates faster bobbing and a subtle lowered weapon offset.
   - Shoot while sprinting: verify recoil kick plays on top of bobbing, crosshair remains stable, and shots register accurately on server.
7. **Horde Escalation**:
   - Observe initial spawn: 5 zombies appear.
   - Survive 2–3 minutes: verify horde escalates steadily up to 25 zombies with rapid 0.7s spawns.
8. **Output Cleanliness**:
   - Confirm Output log contains no repeating errors or warnings.
