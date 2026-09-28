# Plan: Visual Combat Pass + Horde Gameplay Fixes

## 1. Current implementation assessment

The project currently possesses a verified, working combat loop:
- **`default.project.json`**: Maps `src/client` -> `StarterPlayer.StarterPlayerScripts.Client`, `src/server` -> `ServerScriptService.Server`, `src/shared` -> `ReplicatedStorage.Shared`.
- **`src/server/PistolServer.luau`**: Authoritative hitscan raycasting from character `Head.Position`, magazine decrement, reload generation tokens (`reloadTokens`), and attribute management (`PistolMagazine`, `PistolReloading`).
- **`src/server/Zombie.luau`**: Procedural 3-part block zombie with discrete state AI, attack cooldown, collision removal on death, and 3-second corpse cleanup.
- **`src/server/ZombieSpawner.luau`**: Gated difficulty timer (begins on first living player), clamped escalation (max 15 alive, min 1.0s interval), and safe alive-count tracking.
- **`src/client/PistolController.luau`**: Captures LMB semi-automatic firing and R manual reload.
- **`src/client/AmmoGui.luau`**: Displays `12 / ∞` or `RELOADING...` reactively from Player attributes.
- **`src/client/Crosshair.luau`**: Centered screen dot with `ResetOnSpawn = false` and `IgnoreGuiInset = true`.
- **`src/client/init.client.luau`**: Client bootstrapper enforcing `CameraMode.LockFirstPerson`, zoom clamp (0.5), and mouse lock.

---

## 2. Gameplay fixes

1. **Permanent Zombie Pursuit (Single-Player)**:
   - For single-player, every living zombie must always pursue the single living player.
   - Distance must never prevent target acquisition. Remove `DetectionRange` from `ZombieConfig.luau`.
   - When the player is alive: zombies continuously move toward `playerRoot.Position` unless within `AttackRange` (4.5 studs).
   - When the player dies: zombies stop moving and cease attacks.
   - When the player respawns: zombies automatically reacquire the new Character and resume pursuit.
2. **Procedural Ring Spawn Separation**:
   - Replace fixed spawn coordinates with a procedural perimeter ring around the living player (`MinSpawnRadius = 55`, `MaxSpawnRadius = 95`).
   - Candidate positions must maintain >= `MinPlayerSpawnDistance` (50 studs) from the player.
   - Candidate positions must maintain >= `MinZombieSeparation` (12 studs) from all currently living zombies.
   - Run up to `MaxSpawnAttempts` (10) attempts per cycle. If no position satisfies separation, skip the spawn for that cycle (never force an overlapping spawn).
3. **Auto-Reload on Empty Fire**:
   - In `PistolController.luau`, if `PistolMagazine == 0` and `PistolReloading == false`, pressing Left Mouse Button invokes `ReloadPistol:FireServer()`.
   - Manual `R` key reload continues working identically. Both inputs route through the same server-authoritative reload path.

---

## 3. Asset inspection findings

### `assets/Zombie.rbxm`
- **VERIFIED**:
  - Full R15 rig hierarchy: `HumanoidRootPart`, `UpperTorso`, `LowerTorso`, `Head`, `RightHand`, `LeftHand`, `RightLowerArm`, `LeftLowerArm`, `RightUpperArm`, `LeftUpperArm`, `RightFoot`, `LeftFoot`, `RightLowerLeg`, `LeftLowerLeg`, `RightUpperLeg`, `LeftUpperLeg`.
  - `Humanoid` instance with an `Animator` child.
  - Standard `Motor6D` joints connecting all 15 body parts.
  - `Animations` folder containing animation objects (`Walk`, `Run`, `Idle`, `DeathAnimation`, `CheerAnim`, `Fall`, `Jump`, etc.).
  - Embedded scripts and modules: `Animate`, `Health`, `NPC`, `RbxNpcSounds`, `Maid`, `Ragdoll`, `RigTypes`, `Configuration`.
- **ASSUMED / REQUIRES RUNTIME INSPECTION**:
  - `NPC`, `Health`, `Ragdoll`, `Maid`, `RigTypes`: Foreign scripts that contain conflicting AI, health, or physics behaviors. Must be sanitized/deleted on clone.
  - `Animate`: May be configured for player character replication rather than server NPCs. Needs clean isolation or direct animation playback via `Animator`.

### `assets/Pistol.rbxm`
- **VERIFIED**:
  - Detailed visual model containing separate parts/meshparts: `Body`, `Slide`, `Mag`, `Trigger`, `IronSight`.
- **ASSUMED / REQUIRES RUNTIME INSPECTION**:
  - Exact native orientation and pivot point relative to hand coordinates.
  - Whether `Body` is pre-assigned as `PrimaryPart` (if not, code must set `PrimaryPart = model:FindFirstChild("Body") or model:FindFirstChildWhichIsA("BasePart")`).

### `assets/Arms.rbxm`
- **VERIFIED**:
  - MeshPart-based arm rig containing `armsmesh`, `AnimationController`, and `InitialPoses`.
- **ASSUMED / REQUIRES RUNTIME INSPECTION**:
  - Native scale and rest pose orientation relative to camera space.
  - Whether bones or hand attachments exist, or whether the pistol should be welded directly to `armsmesh`.

---

## 4. Rojo asset mapping

To make assets accessible to both server and client without manual Studio importing, update `default.project.json` under `ReplicatedStorage`:

```json
    "ReplicatedStorage": {
      "Shared": {
        "$path": "src/shared"
      },
      "Assets": {
        "$path": "assets"
      }
    },
```

- **Runtime Hierarchy**:
  - `ReplicatedStorage.Assets.Zombie` (Model template)
  - `ReplicatedStorage.Assets.Pistol` (Model template)
  - `ReplicatedStorage.Assets.Arms` (Model template)
- Server clones `ReplicatedStorage.Assets.Zombie` for NPC spawning.
- Client clones `ReplicatedStorage.Assets.Arms` and `ReplicatedStorage.Assets.Pistol` for the FPS viewmodel.

---

## 5. Imported zombie runtime sanitization

When `Zombie.spawn` clones `ReplicatedStorage.Assets.Zombie`, it must sanitize the clone before adding it to `Workspace`:
1. **Strip Conflicting Scripts**:
   - Recursively find and `Destroy()` foreign script objects:
     `NPC`, `Health`, `Ragdoll`, `Maid`, `RigTypes`, `RbxNpcSounds`, `Configuration`.
   - Ensures zero foreign logic runs, preserving 100% server authority in `Zombie.luau`.
2. **Preserve Presentation Data**:
   - Keep all `MeshPart`s, `Motor6D`s, `Attachments`, `HumanoidRootPart`, `Humanoid`, `Animator`, and the `Animations` folder.
3. **Configure Humanoid & Rig**:
   - `humanoid.MaxHealth = ZombieConfig.MaxHealth`
   - `humanoid.Health = ZombieConfig.MaxHealth`
   - `humanoid.WalkSpeed = ZombieConfig.WalkSpeed`
   - `humanoid.BreakJointsOnDeath = false` (prevents dismemberment on death).
   - `model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")`
4. **Gameplay Attributes & Tagging**:
   - `model:SetAttribute("IsZombie", true)`
   - `model:SetAttribute("IsDead", false)`
   - `CollectionService:AddTag(model, "Zombie")`
5. **Physics Ownership**:
   - Parent clone to `Workspace`.
   - `pcall(function() model.PrimaryPart:SetNetworkOwner(nil) end)` to enforce server physics authority.

---

## 6. Zombie rig integration

In `src/server/Zombie.luau`, replace the procedural block-part generator with a template cloner:

```luau
local function createRig(spawnPosition)
    local Assets = ReplicatedStorage:WaitForChild("Assets")
    local template = Assets:WaitForChild("Zombie")
    local model = template:Clone()

    -- Sanitize foreign scripts
    for _, child in model:GetDescendants() do
        if child:IsA("Script") or child:IsA("ModuleScript") then
            if child.Name ~= "Animate" then
                child:Destroy()
            end
        end
    end

    local humanoid = model:WaitForChild("Humanoid")
    local root = model:WaitForChild("HumanoidRootPart")
    model.PrimaryPart = root

    humanoid.MaxHealth = ZombieConfig.MaxHealth
    humanoid.Health = ZombieConfig.MaxHealth
    humanoid.WalkSpeed = ZombieConfig.WalkSpeed
    humanoid.BreakJointsOnDeath = false

    model:PivotTo(CFrame.new(spawnPosition))
    return model, root, humanoid
end
```

The rest of `Zombie.spawn()` (death handler, collision disabling, spawner callback, 3s delayed destruction, and AI pursuit loop) remains unchanged.

---

## 7. Zombie animation strategy

To avoid foreign animation script bugs while leveraging the imported animation assets:
- Inside `assets/Zombie.rbxm`, locate `Animations.Idle` and `Animations.Walk` (or `Run`).
- In `Zombie.luau`, obtain the `Animator` child of `Humanoid`:
  ```luau
  local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
  local animations = model:FindFirstChild("Animations")
  local idleTrack, walkTrack
  if animations then
      local idleAnim = animations:FindFirstChild("Idle")
      local walkAnim = animations:FindFirstChild("Walk") or animations:FindFirstChild("Run")
      if idleAnim then idleTrack = animator:LoadAnimation(idleAnim) end
      if walkAnim then walkTrack = animator:LoadAnimation(walkAnim) end
  end
  ```
- **Playback Control**:
  - Start `idleTrack:Play()` upon spawn.
  - In the AI loop (or via `humanoid.Running` event):
    - When moving (`humanoid.MoveDirection.Magnitude > 0.1`): crossfade to `walkTrack`.
    - When stationary: crossfade to `idleTrack`.
  - On death: stop all tracks immediately.
- Animations remain strictly visual and never dictate movement or damage timing.

---

## 8. Zombie targeting strategy

- **Single-Player Policy**:
  - In `src/shared/ZombieConfig.luau`: remove `DetectionRange = 100`.
  - In `src/server/Zombie.luau`, `nearestLivingPlayer()` iterates `Players:GetPlayers()` and selects the single living player whose character is in `workspace` with `humanoid.Health > 0`.
  - There is NO maximum distance check. As long as the player is alive, the zombie moves toward `playerRoot.Position` via `humanoid:MoveTo`.
  - If the player dies (`Health <= 0`), the zombie halts (`humanoid:MoveTo(root.Position)`).
  - When the player respawns, zombies detect the new living Character on their next 0.2s tick and resume pursuit automatically.

---

## 9. Spawn separation algorithm

- **Parameters in `src/shared/HordeConfig.luau`**:
  ```luau
  return {
      -- Progression
      InitialMaxAlive = 3,
      MaximumMaxAlive = 15,
      InitialSpawnInterval = 4.0,
      MinimumSpawnInterval = 1.0,
      DifficultyStepSeconds = 25,
      MaxAliveIncreasePerStep = 2,
      SpawnIntervalDecreasePerStep = 0.5,
      CorpseCleanupDelay = 3.0,

      -- Separation & Geometry
      MinSpawnRadius = 55,         -- Minimum ring radius from player (studs)
      MaxSpawnRadius = 95,         -- Maximum ring radius from player (studs)
      MinPlayerSpawnDistance = 50, -- Safety buffer from player (studs)
      MinZombieSeparation = 12,    -- Safety buffer from other living zombies (studs)
      MaxSpawnAttempts = 10,       -- Max candidate attempts before skipping cycle
      ArenaRadiusLimit = 220,      -- Boundary check for 512x512 Baseplate
  }
  ```
- **Algorithm in `src/server/ZombieSpawner.luau`**:
  ```luau
  local function chooseSpawnPoint(playerRoot, livingZombieRoots)
      local playerPos = playerRoot.Position
      for attempt = 1, HordeConfig.MaxSpawnAttempts do
          local angle = math.random() * math.pi * 2
          local radius = math.random(HordeConfig.MinSpawnRadius, HordeConfig.MaxSpawnRadius)
          local candidate = Vector3.new(
              playerPos.X + radius * math.cos(angle),
              3,
              playerPos.Z + radius * math.sin(angle)
          )

          -- 1. Arena boundary check
          if math.abs(candidate.X) < HordeConfig.ArenaRadiusLimit and math.abs(candidate.Z) < HordeConfig.ArenaRadiusLimit then
              -- 2. Player distance check
              if (candidate - playerPos).Magnitude >= HordeConfig.MinPlayerSpawnDistance then
                  -- 3. Zombie-to-zombie separation check
                  local separated = true
                  for _, zombieRoot in livingZombieRoots do
                      if (candidate - zombieRoot.Position).Magnitude < HordeConfig.MinZombieSeparation then
                          separated = false
                          break
                      end
                  end
                  if separated then
                      return candidate
                  end
              end
          end
      end
      return nil -- No valid candidate found; skip cycle safely
  end
  ```
- Living zombie roots are gathered by scanning `CollectionService:GetTagged("Zombie")` models where `GetAttribute("IsDead") ~= true`.

---

## 10. Auto reload implementation

- **In `src/client/PistolController.luau`**:
  ```luau
  if input.UserInputType == Enum.UserInputType.MouseButton1 then
      if mouseDown then return end
      mouseDown = true
      if gameProcessed then return end

      local character = player.Character
      local humanoid = character and character:FindFirstChildOfClass("Humanoid")
      if not humanoid or humanoid.Health <= 0 or player:GetAttribute("PistolReloading") == true then
          return
      end

      local magazine = player:GetAttribute("PistolMagazine") or 0
      if magazine > 0 then
          local now = os.clock()
          if lastShotTime and now - lastShotTime < PistolConfig.FireRate then return end
          local camera = workspace.CurrentCamera
          if not camera then return end
          lastShotTime = now
          firePistol:FireServer(camera.CFrame.LookVector)
          ViewmodelController.playFireFeedback()
      else
          -- Magazine is 0 and player is not reloading -> Auto Reload!
          reloadPistol:FireServer()
      end
  ```
- **Server (`PistolServer.luau`)**: Requires zero modifications. It already validates reload state and triggers the reload cycle authoritatively.

---

## 11. FPS Viewmodel architecture

- **Component**: `src/client/ViewmodelController.luau`.
- **Role**: Client-side visual viewmodel manager.
- **Hierarchy**:
  ```
  workspace.CurrentCamera
  └── Viewmodel (Model)
      ├── Arms (cloned from ReplicatedStorage.Assets.Arms)
      │   └── armsmesh (MeshPart)
      └── Pistol (cloned from ReplicatedStorage.Assets.Pistol)
          ├── Body (PrimaryPart)
          ├── Slide
          └── Mag
  ```
- **Properties on all Viewmodel BaseParts**:
  - `CanCollide = false`
  - `CanTouch = false`
  - `CanQuery = false` (raycasts pass through viewmodel completely)
  - `CastShadow = false`
  - `Massless = true`
- **Isolation**: Viewmodel exists strictly on the local client. The server never sees it.

---

## 12. Arms asset integration

- Cloned from `ReplicatedStorage.Assets.Arms`.
- Sanitized on client: ensure all scripts (if any) are removed; preserve `armsmesh` and joints.
- Scale adjusted via `ViewmodelConfig.ArmsScale` if needed.
- Designate `armsmesh` as `Arms.PrimaryPart`.

---

## 13. Pistol asset integration

- Cloned from `ReplicatedStorage.Assets.Pistol`.
- Designate `Pistol.PrimaryPart = pistol:FindFirstChild("Body") or pistol:FindFirstChildWhichIsA("BasePart")`.
- Scale adjusted via `ViewmodelConfig.PistolScale` if needed.
- Internal component parts (`Slide`, `Mag`, `Trigger`) remain welded to `Body` so future reload/slide animations are supported.

---

## 14. Pistol attachment strategy

- **Decision**: **Roblox-native `WeldConstraint`**.
- **Attachment Sequence**:
  1. Position the Pistol relative to the Arms using configuration:
     `pistol:PivotTo(arms.PrimaryPart.CFrame * ViewmodelConfig.PistolOffset)`
  2. Create a `WeldConstraint`:
     ```luau
     local weld = Instance.new("WeldConstraint")
     weld.Name = "PistolWeld"
     weld.Part0 = arms.PrimaryPart
     weld.Part1 = pistol.PrimaryPart
     weld.Parent = pistol.PrimaryPart
     ```
- **Why this method**:
  - `WeldConstraint` locks the exact relative transform established at spawn without complex C0/C1 matrix calculations.
  - Immune to physics engine drift and parent changes.

---

## 15. Viewmodel camera update

- **Camera Binding**:
  - Use `RunService.RenderStepped:Connect(function(dt) ... )` (or `RunService:BindToRenderStep("ViewmodelUpdate", Enum.RenderPriority.Camera.Value + 1, ...)`).
  - Every rendered frame, position the viewmodel root at:
    `local targetCFrame = camera.CFrame * ViewmodelConfig.CameraOffset * currentRecoilOffset`
    `viewmodel:PivotTo(targetCFrame)`
  - Smooth recoil decay:
    `currentRecoilOffset = currentRecoilOffset:Lerp(CFrame.identity, math.clamp(dt * ViewmodelConfig.RecoilRecoverySpeed, 0, 1))`
- **Idempotency**: Connect the render loop once on client startup, toggling an active flag or managing one single connection to prevent duplicate loops across respawns.

---

## 16. Viewmodel transforms/config

Create `src/client/ViewmodelConfig.luau` to centralize all offsets for Studio tuning:

```luau
return {
    -- Camera-relative offset (right, up, forward)
    CameraOffset = CFrame.new(0, -1.2, -1.5),

    -- Arms-to-Pistol relative offset and rotation
    PistolOffset = CFrame.new(0.35, -0.2, -0.6) * CFrame.Angles(0, math.rad(180), 0),

    -- Scale adjustments
    ArmsScale = Vector3.new(1, 1, 1),
    PistolScale = Vector3.new(1, 1, 1),

    -- Firing feedback kick
    RecoilKick = CFrame.new(0, 0.03, 0.08) * CFrame.Angles(math.rad(2.5), 0, 0),
    RecoilRecoverySpeed = 12,
}
```

*Note: Studio testing will be used to fine-tune exact numbers in this file.*

---

## 17. First-person real character visibility

- In `ViewmodelController.luau`, when the player's Character spawns:
  - Iterate through `character:GetDescendants()`.
  - For any `BasePart`: set `part.LocalTransparencyModifier = 1`.
  - Connect to `character.DescendantAdded` to set `LocalTransparencyModifier = 1` on newly attached accessories.
  - In the `RenderStepped` loop, ensure `character` parts maintain `LocalTransparencyModifier = 1`.
- **Safety**: `LocalTransparencyModifier` affects only the local camera view; server replication and other players' views are completely untouched.

---

## 18. Fire/reload visual behavior

- **Fire Feedback**:
  - `ViewmodelController.playFireFeedback()` sets `currentRecoilOffset = ViewmodelConfig.RecoilKick`.
  - Decays smoothly to `CFrame.identity` via `Lerp` in `RenderStepped`.
  - No complex recoil frameworks or camera shake scripts needed.
- **Reload Feedback**:
  - `AmmoGui` displays `RELOADING...` for the full 1.5 seconds.
  - Arms and pistol remain visible in front of the camera.

---

## 19. Respawn lifecycle

- **Player Death (`Humanoid.Died`)**:
  - Viewmodel model is destroyed (`viewmodel:Destroy()`).
  - Recoil offset resets to `CFrame.identity`.
  - Zombies halt pursuit.
- **Player Respawn (`CharacterAdded`)**:
  - Reconstruct Viewmodel cleanly from templates.
  - Re-parent to `CurrentCamera`.
  - Enforce `LocalTransparencyModifier = 1` on new character parts.
  - Living zombies reacquire the new Character on their next 0.2s tick.
  - Spawner resumes spawning.

---

## 20. Files to create

1. **`src/client/ViewmodelConfig.luau`**: Centralized offsets, scales, and recoil parameters for Studio tuning.
2. **`src/client/ViewmodelController.luau`**: Client viewmodel manager (cloning, welding, camera update, recoil kick, and character transparency).

---

## 21. Files to modify

1. **`default.project.json`**: Map `"Assets": { "$path": "assets" }` into `ReplicatedStorage`.
2. **`src/shared/ZombieConfig.luau`**: Remove `DetectionRange`.
3. **`src/shared/HordeConfig.luau`**: Replace fixed `SpawnPoints` with ring separation parameters (`MinSpawnRadius`, `MaxSpawnRadius`, `MinPlayerSpawnDistance`, `MinZombieSeparation`, `MaxSpawnAttempts`, `ArenaRadiusLimit`).
4. **`src/server/Zombie.luau`**: Clone from `ReplicatedStorage.Assets.Zombie`, sanitize foreign scripts, setup native locomotion animations, and implement permanent pursuit.
5. **`src/server/ZombieSpawner.luau`**: Implement procedural ring spawn selection with player distance and zombie separation checks.
6. **`src/client/PistolController.luau`**: Trigger auto-reload on empty LMB fire; trigger `ViewmodelController.playFireFeedback()` on fire.
7. **`src/client/init.client.luau`**: Start `ViewmodelController.start()`.

---

## 22. Files that must remain unchanged

- **`src/server/PistolServer.luau`**: Authoritative hitscan raycast from player Head, magazine decrement, and server reload timing remain 100% authoritative and unchanged.
- **`src/shared/PistolConfig.luau`**: Pistol stats (`Damage = 25`, `Range = 300`, `FireRate = 0.2`, `MagazineSize = 12`, `ReloadDuration = 1.5`) remain unchanged.
- **`src/shared/Remotes.luau`**: Networking contract remains `FirePistol` and `ReloadPistol`.
- **`src/client/Crosshair.luau`**: Persistent crosshair dot remains unchanged.
- **`src/client/AmmoGui.luau`**: UI rendering (`12 / ∞` and `RELOADING...`) remains unchanged.

---

## 23. Implementation order

1. **Rojo Mapping**: Update `default.project.json` to map `assets` to `ReplicatedStorage.Assets`.
2. **Configuration Updates**:
   - In `src/shared/ZombieConfig.luau`, remove `DetectionRange`.
   - In `src/shared/HordeConfig.luau`, replace `SpawnPoints` with ring separation parameters.
3. **Zombie Sanitization & Asset Integration**:
   - In `src/server/Zombie.luau`, clone `Assets.Zombie`, sanitize foreign scripts, connect locomotion animations, and update target selection to permanent pursuit.
4. **Spawner Ring Separation**:
   - In `src/server/ZombieSpawner.luau`, implement procedural ring candidate generation with player buffer and zombie-to-zombie separation checks.
5. **Viewmodel Modules**:
   - Create `src/client/ViewmodelConfig.luau`.
   - Create `src/client/ViewmodelController.luau` (cloning, welding, `RenderStepped` camera update, recoil kick, avatar transparency, respawn handling).
6. **PistolController Integration**:
   - In `src/client/PistolController.luau`, add auto-reload when LMB is pressed with magazine == 0, and invoke `ViewmodelController.playFireFeedback()` on valid shot.
7. **Client Bootstrap**:
   - In `src/client/init.client.luau`, require and call `ViewmodelController.start()`.
8. **Static Verification**:
   - Inspect `git diff`, run `git diff --check`, and update `AI/IMPLEMENTATION.md`.

---

## 24. Risks and edge cases

- **Foreign Zombie Scripts Intercepting AI**:
  - *Risk*: Embedded scripts (`NPC`, `Ragdoll`) in `Zombie.rbxm` seize control of movement or health.
  - *Mitigation*: Sanitization loop explicitly destroys all `Script` and `ModuleScript` instances inside the clone before parenting to `Workspace`.
- **Viewmodel Intercepting Raycasts**:
  - *Risk*: Pistol hitscan raycasts collide with viewmodel arms/body.
  - *Mitigation*: Set `CanQuery = false` and `CanCollide = false` on every BasePart in the viewmodel. Furthermore, server casts rays from `player.Character.Head.Position` (not the viewmodel).
- **Viewmodel Duplication on Respawn**:
  - *Risk*: Multiple viewmodels appear on respawn.
  - *Mitigation*: `ViewmodelController` destroys any pre-existing `"Viewmodel"` model in `CurrentCamera` before creating a new one.
- **Real Avatar Clipping in Viewmodel**:
  - *Risk*: Player's default arms/shoulders clip through the first-person viewmodel.
  - *Mitigation*: Set `LocalTransparencyModifier = 1` on all character parts in `RenderStepped`.
- **Spawn Candidate Starvation**:
  - *Risk*: If the arena is crowded or player is near corners, 10 attempts fail to find a valid separated spot.
  - *Mitigation*: The spawner safely skips that cycle and tries again next iteration; it never forces an overlapping spawn.
- **Pistol Auto-Reload Remote Spam**:
  - *Risk*: Rapidly clicking with an empty magazine spams `ReloadPistol:FireServer()`.
  - *Mitigation*: Client checks `player:GetAttribute("PistolReloading") ~= true` and server rejects reload if already reloading.

---

## 25. Verification checklist

### Manual Roblox Studio Verification Checklist
1. **Gameplay & Combat**:
   - Every living zombie continuously chases the player across the entire Baseplate (no detection dropoff).
   - Zombies spawn separated around the player; no zombies spawn overlapping or clustered together.
   - Fire all 12 rounds: click LMB with 0 ammo -> auto-reload begins immediately (`RELOADING...`).
   - Press R with 5 rounds: manual reload works as before.
   - Pistol raycasts deal 25 damage per hit; 4 shots kill the imported zombie.
   - Dead zombie loses collisions immediately and model disappears after 3 seconds.
2. **Visual Presentation**:
   - Imported 3D zombie model appears in the arena instead of the old block rig.
   - Zombie plays walking locomotion animation while pursuing the player.
   - First-person arms and pistol appear smoothly in front of the camera.
   - Pistol moves in unison with the arms.
   - Firing produces a subtle recoil kick that smoothly recovers.
   - Real character avatar parts do not clip into view.
3. **Lifecycle & Respawn**:
   - Die to the horde: viewmodel disappears cleanly, zombies halt pursuit.
   - Respawn: viewmodel reappears cleanly (exactly 1 instance), pistol fires/reloads, zombies reacquire the player.
   - Output console remains clean with zero repeating warnings or errors.

---

## 26. Definition of done

The milestone is complete when:
1. Every living zombie permanently pursues the single player.
2. Zombies spawn via procedural ring separation without clustering or spawning on top of the player.
3. Empty magazine LMB click triggers auto-reload seamlessly.
4. Imported R15 zombie model replaces procedural block rig and plays locomotion animation.
5. First-person viewmodel displaying arms holding the pistol follows camera smoothly without collision or avatar clipping.
6. The entire combat loop survives player death and respawn without errors or performance degradation.
