# Plan: Pistol + Basic Zombie Combat Vertical Slice

## 1. Current project assessment

The project currently has a working first-person camera foundation synchronized via Rojo 7.7.0:
- **Client (`src/client/`)**:
  - `init.client.luau`: Boots client-side systems, locks camera to `Enum.CameraMode.LockFirstPerson`, clamps min/max zoom to `0.5`, manages `MouseIconEnabled` via `GuiService.MenuOpened`/`MenuClosed`, and mounts the crosshair.
  - `Crosshair.luau`: Creates and mounts a centered dot crosshair into `PlayerGui` with `ResetOnSpawn = false` and `IgnoreGuiInset = true`.
- **Server (`src/server/`)**:
  - `init.server.luau`: Minimal starter script printing a test message. No gameplay systems exist yet.
- **Shared (`src/shared/`)**:
  - `Hello.luau`: Obsolete example module returning a print function.
- **Rojo mappings (`default.project.json`)**:
  - Maps `src/client` -> `StarterPlayer.StarterPlayerScripts.Client`
  - Maps `src/server` -> `ServerScriptService.Server`
  - Maps `src/shared` -> `ReplicatedStorage.Shared`
  - Workspace contains a static 512x20x512 Baseplate at `(0, -10, 0)`.
- **Reusability**:
  - The first-person lock, mouse behavior, and crosshair UI in `src/client` are fully functioning and will be preserved intact.
  - Standard Roblox character movement is preserved without custom movement scripts.
  - Remotes and Player Attributes will be used for networking and state synchronization.

---

## 2. Proposed architecture

The architecture consists of two synchronized loops: the Player Combat Loop and the Zombie AI Loop.

```
PLAYER CLIENT                                       SERVER
┌─────────────────────────────────┐                 ┌───────────────────────────────────┐
│ User Input (LMB / R)            │                 │ Remote Listeners (PistolServer)   │
│ ├─ Check client cooldown/mag    │                 │ ├─ Validate cooldown & ammo       │
│ ├─ Get camera aim LookVector    │                 │ ├─ Origin = Character.Head.Pos    │
│ └─ FirePistol(aimDirection) ───►│ ──────────────► │ ├─ Execute authoritative raycast  │
│                                 │                 │ ├─ Decrement PistolMagazine attr  │
│ Player Attributes Listener      │                 │ ├─ If hit Zombie -> TakeDamage    │
│ ├─ PistolMagazine               │                 │ └─ Update Player Attributes:      │
│ ├─ PistolReserve                │ ◄────────────── │    - PistolMagazine               │
│ └─ PistolReloading              │ (Replicated     │    - PistolReserve                │
│    └─ Updates AmmoGui text      │  Attributes)    │    - PistolReloading              │
└─────────────────────────────────┘                 └───────────────────────────────────┘

ZOMBIE AI (SERVER AUTHORITATIVE)
┌───────────────────────────────────────────────────────────────────────────────────────┐
│ Heartbeat / Task Loop (Zombie.luau)                                                   │
│ ├─ Scan players for nearest living character (Humanoid.Health > 0)                    │
│ ├─ If target in detection range:                                                      │
│ │   ├─ Distance > AttackRange ──► Humanoid:MoveTo(targetRoot.Position)                │
│ │   └─ Distance <= AttackRange ─► Cooldown ready? -> playerHumanoid:TakeDamage(dmg)   │
│ └─ If Zombie Humanoid.Health <= 0 ─► Stop behavior, disable AI, mark dead             │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

**Key Architectural Decisions**:
1. **Ammo State Synchronization via Player Attributes**: Instead of an `AmmoUpdated` RemoteEvent, the server sets attributes (`PistolMagazine`, `PistolReserve`, `PistolReloading`) directly on the `Player` instance. Attributes automatically replicate to the client, are immediately available upon client join or character respawn without listener race conditions, and can be listened to reactively with `GetAttributeChangedSignal`.
2. **Server-Owned Remotes**: Only two client-to-server remotes exist (`FirePistol` and `ReloadPistol`). They are instantiated strictly by the server upon initialization under `ReplicatedStorage.Remotes`. The client strictly waits for them via `WaitForChild`.
3. **Single Raycast Contract (`FirePistol(aimDirection)`)**: The client sends only the normalized camera `LookVector`. The server derives the ray origin from the player's `Character.Head.Position`, calculates range, performs the raycast, and resolves damage authoritatively.
4. **Streamlined Welded Zombie Rig**: The prototype zombie uses a simple, robust 3-part model (`HumanoidRootPart` + `Torso` + `Head`) connected via `WeldConstraint` with `HipHeight = 2.0`, eliminating complex Motor6D joint offsets while guaranteeing reliable `Humanoid:MoveTo` walking on the Baseplate.

---

## 3. Existing files to modify

1. **`src/client/init.client.luau`**:
   - **Why**: Acts as the client bootstrap.
   - **Responsibility**: Initialize `PistolController` and `AmmoGui` alongside existing camera/crosshair initialization.
2. **`src/server/init.server.luau`**:
   - **Why**: Acts as the server bootstrap.
   - **Responsibility**: Initialize server remotes, start `PistolServer`, and spawn the prototype `Zombie`.

*(Note: `src/shared/Hello.luau` is an obsolete starter template and is left untouched).*

---

## 4. Files to create

1. **`src/shared/PistolConfig.luau`**:
   - Shared weapon constants: damage, range, fire rate (cooldown), magazine size, default reserve, and reload time.
2. **`src/shared/ZombieConfig.luau`**:
   - Shared zombie constants: max health, walk speed, attack range, attack damage, attack cooldown, and detection range.
3. **`src/shared/Remotes.luau`**:
   - Remote access module. Provides `Remotes.initServer()` to create the `Remotes` folder and RemoteEvents on the server, and `Remotes.getClient()` which only waits for them on the client, ensuring the client cannot create server networking objects.
4. **`src/server/PistolServer.luau`**:
   - Server weapon authority. Initializes player ammo attributes, listens to `FirePistol` and `ReloadPistol`, validates shot requests and fire rate, performs server-authoritative raycasts, and applies damage.
5. **`src/server/Zombie.luau`**:
   - Server zombie controller and spawner. Programmatically constructs the welded prototype zombie model, runs the detection/chase/attack AI loop, and handles death cleanup.
6. **`src/client/PistolController.luau`**:
   - Client weapon input. Captures mouse clicks (semi-automatic enforcement), requests reloads on `R`, tracks local fire-rate cooldown, obtains camera `LookVector`, and invokes `FirePistol`.
7. **`src/client/AmmoGui.luau`**:
   - Minimal prototype UI displaying current magazine and reserve ammo (`12 / 60` or `RELOADING...`). Reads from and listens to `Player` attributes; mounted in `PlayerGui` with `ResetOnSpawn = false`.

---

## 5. Shared configuration

Configuration modules reside in `src/shared` (synchronized to `ReplicatedStorage.Shared`) so both client and server reference the same numbers without duplication:

- **`src/shared/PistolConfig.luau`**:
  ```luau
  return {
      Damage = 25,           -- 3-4 body shots to kill an 80 HP zombie
      Range = 300,           -- Maximum hitscan raycast distance in studs
      FireRate = 0.2,        -- Minimum seconds between shots (5 shots/sec max)
      MagazineSize = 12,     -- Maximum ammo per magazine
      DefaultReserve = 60,   -- Starting reserve ammo
      ReloadDuration = 1.5,  -- Seconds required to complete a reload
  }
  ```
- **`src/shared/ZombieConfig.luau`**:
  ```luau
  return {
      MaxHealth = 80,
      WalkSpeed = 12,        -- Slightly slower than default player speed (16)
      DetectionRange = 100,  -- Studs within which zombie detects a living player
      AttackRange = 4.5,     -- Studs distance required to strike
      AttackDamage = 15,     -- Damage per melee hit
      AttackCooldown = 1.2,  -- Seconds between zombie attacks
  }
  ```
- **Authority rule**: While configuration is visible to the client (for client-side cooldown prediction and UI formatting), the **server enforces all limits** independently. If a client attempts to shoot faster than `PistolConfig.FireRate`, the server ignores the request.

---

## 6. Pistol client architecture

- **Input Handling**:
  - Bound via `UserInputService.InputBegan`.
  - `Enum.UserInputType.MouseButton1`: Semi-automatic trigger. Checks if already clicking, reloading, or on fire-rate cooldown. Only fires once per click.
  - `Enum.KeyCode.R`: Reload trigger. Checks if magazine is already full, reserve is 0, or already reloading.
- **Aim Calculation**:
  - Because `CameraMode.LockFirstPerson` is active, the crosshair is at the exact center of the screen.
  - The client extracts `aimDirection = workspace.CurrentCamera.CFrame.LookVector`.
- **Client Prediction & Network**:
  - When LMB is pressed and valid, client sends `FirePistol:FireServer(aimDirection)`.
  - Client predicts fire cooldown locally (`lastShotTime = os.clock()`) to prevent network spam.
  - Client does NOT decide ray origin, hit victim, or damage.
- **Ammo Synchronization & UI Integration**:
  - Handled via `Player` attributes: `PistolMagazine`, `PistolReserve`, `PistolReloading`.
  - `AmmoGui.luau` reads current values immediately upon mount via `player:GetAttribute()`.
  - Listens to changes via `player:GetAttributeChangedSignal("PistolMagazine")`, etc.
  - Formats text as `12 / 60` or `RELOADING...`.
- **Respawn Handling**:
  - Input listeners in `PistolController` are connected once in `StarterPlayerScripts`.
  - Because attributes reside on the `Player` instance (not `Character`), ammo state survives respawns seamlessly and updates immediately when the server resets them.

---

## 7. Pistol server architecture

- **Remote Ownership**:
  - `Remotes.initServer()` creates a `Folder` named `"Remotes"` inside `ReplicatedStorage` (if missing).
  - Creates two `RemoteEvent` instances inside it:
    - `FirePistol`
    - `ReloadPistol`
- **State Management via Player Attributes**:
  - On `PlayerAdded` / `CharacterAdded`, server sets attributes on `player`:
    - `player:SetAttribute("PistolMagazine", PistolConfig.MagazineSize)`
    - `player:SetAttribute("PistolReserve", PistolConfig.DefaultReserve)`
    - `player:SetAttribute("PistolReloading", false)`
  - Internal server table tracks per-player cooldowns: `lastShotTimes[player] = 0`.
  - On `PlayerRemoving`, server cleans up `lastShotTimes[player]`.
- **Validation on `FirePistol(player, aimDirection)`**:
  1. Verify player has an alive character (`character` in workspace and `Humanoid.Health > 0`).
  2. Verify player is not reloading (`player:GetAttribute("PistolReloading") ~= true`).
  3. Verify `os.clock() - (lastShotTimes[player] or 0) >= (PistolConfig.FireRate - 0.05)` (small tolerance for latency jitter).
  4. Verify current magazine has ammo (`(player:GetAttribute("PistolMagazine") or 0) > 0`).
  5. Verify `typeof(aimDirection) == "Vector3"` and direction values are finite and non-zero (`aimDirection.Magnitude > 0.5`).
- **Hit Resolution**:
  - Decrement `player:SetAttribute("PistolMagazine", mag - 1)`.
  - Update `lastShotTimes[player] = os.clock()`.
  - Determine origin: `character.Head.Position`.
  - Normalize direction: `direction = aimDirection.Unit * PistolConfig.Range`.
  - Perform `workspace:Raycast(origin, direction, raycastParams)`.
  - If raycast hits an instance: locate ancestor Model with a `Humanoid` tagged/named as Zombie.
  - If valid zombie found (`zombieHumanoid.Health > 0`): apply `zombieHumanoid:TakeDamage(PistolConfig.Damage)`.
- **Validation on `ReloadPistol(player)`**:
  1. Verify player is alive and not already reloading.
  2. Verify `mag < PistolConfig.MagazineSize` and `reserve > 0`.
  3. Set `player:SetAttribute("PistolReloading", true)`.
  4. Use `task.delay(PistolConfig.ReloadDuration, ...)`:
     - Check player is still connected and alive.
     - Calculate ammo transfer: `needed = PistolConfig.MagazineSize - mag`, `transfer = math.min(needed, reserve)`.
     - Update attributes: `PistolMagazine = mag + transfer`, `PistolReserve = reserve - transfer`, `PistolReloading = false`.

---

## 8. Raycast strategy

- **Contract**: Single, unambiguous contract everywhere:
  - **Client sends**: `FirePistol:FireServer(aimDirection)` where `aimDirection = camera.CFrame.LookVector`.
  - **Server determines**:
    - Ray Origin: `player.Character.Head.Position`.
    - Ray Direction: `aimDirection.Unit * PistolConfig.Range`.
    - RaycastParams: `FilterType = RaycastFilterType.Exclude`, `FilterDescendantsInstances = { player.Character }`.
- **Why this contract**:
  - Prevents all origin-spoofing and hit-injection exploits.
  - Eliminates any ambiguity: the client never sends positions, rays, or victim instances.
  - For an NPC moving at normal walkspeed on a flat arena, server raycasting from the player's head along their camera look vector provides responsive, accurate hit detection.

---

## 9. Zombie architecture

- **Entity Model**:
  - Standard Roblox `Model` named `"Zombie"`.
  - Marked with attribute `model:SetAttribute("IsZombie", true)` and tagged with `CollectionService:AddTag(model, "Zombie")`.
- **Rig Structure (Streamlined 3-Part Rig)**:
  - `HumanoidRootPart` (Size: `2, 2, 1`, Transparency: `1`, CanCollide: `false`, Anchored: `false`). Set as `Model.PrimaryPart`.
  - `Torso` (Size: `2, 2, 1`, Color: dark gray/blue, CanCollide: `true`, Anchored: `false`). Attached to `HumanoidRootPart` via `WeldConstraint`.
  - `Head` (Size: `1.25, 1.25, 1.25`, Color: zombie green `Color3.fromRGB(75, 130, 75)`, CanCollide: `true`, Anchored: `false`). Attached to `Torso` via `WeldConstraint`.
  - `Humanoid` instance:
    - `MaxHealth = ZombieConfig.MaxHealth` (80)
    - `Health = ZombieConfig.MaxHealth`
    - `WalkSpeed = ZombieConfig.WalkSpeed` (12)
    - `HipHeight = 2.0` (essential: allows the Humanoid to stand and walk smoothly above the Baseplate).
- **Behavior Loop**:
  - Managed by `Zombie.luau` via `task.spawn` running a stepped/heartbeat loop:
    - `IDLE`: Scans players for nearest living character (`Humanoid.Health > 0`).
    - `CHASE`: If target distance > `ZombieConfig.AttackRange`, calls `humanoid:MoveTo(targetRoot.Position)`.
    - `ATTACK`: If target distance <= `ZombieConfig.AttackRange`, checks attack cooldown (`os.clock() - lastAttack >= ZombieConfig.AttackCooldown`). Deals `ZombieConfig.AttackDamage` (15) to `playerHumanoid:TakeDamage(...)`.
    - `DEAD`: On `Humanoid.Died`, terminates loop, stops movement, anchors root part or disables collisions.

---

## 10. Zombie movement strategy

- **Decision**: **Roblox-native `Humanoid:MoveTo`**.
- **Reasoning**:
  - The test arena is a flat 512x512 Baseplate with zero obstacles.
  - `Humanoid:MoveTo(targetPosition)` is built into the engine, requires zero path computation overhead, and moves directly toward the player smoothly.
  - With `HipHeight = 2.0` and welded parts, the unanchored model navigates the Baseplate cleanly.
  - When complex indoor geometry is added in future milestones, `PathfindingService` can replace `Humanoid:MoveTo` inside `Zombie.luau` without affecting combat systems.

---

## 11. Damage model

- **Pistol -> Zombie**:
  - Triggered exclusively on the server after raycast hit confirmation.
  - Uses `zombieHumanoid:TakeDamage(PistolConfig.Damage)`.
  - At 0 HP, `zombieHumanoid.Died` fires and the zombie stops.
- **Zombie -> Player**:
  - Triggered exclusively on the server in the zombie AI loop.
  - When distance between `zombie.HumanoidRootPart` and `player.HumanoidRootPart` <= `ZombieConfig.AttackRange`.
  - Checks attack cooldown: `os.clock() - lastAttackTime >= ZombieConfig.AttackCooldown`.
  - Uses `playerHumanoid:TakeDamage(ZombieConfig.AttackDamage)`.
  - Does NOT apply damage if either the zombie or the player is dead (`Health <= 0`).

---

## 12. Respawn and lifecycle

- **Player Death**:
  - When the player's Humanoid dies:
    - Server cancels active reload for that player (`player:SetAttribute("PistolReloading", false)`).
    - Zombie AI detects `targetHumanoid.Health <= 0`, halts movement, and clears its target reference.
- **Player Respawn**:
  - Handled via `Player.CharacterAdded`:
    - Server resets player ammo attributes (`PistolMagazine = 12, PistolReserve = 60, PistolReloading = false`).
    - Attributes replicate automatically, immediately updating `AmmoGui`.
    - Client `PistolController` internal firing/cooldown flags reset.
    - `AmmoGui` and `CrosshairGui` remain mounted because `ResetOnSpawn = false`.
    - Zombie AI detects the new living Character and resumes chase when in range.
- **Zombie Death**:
  - Handled via `zombieHumanoid.Died`:
    - Breaks the AI loop immediately.
    - Anchors `HumanoidRootPart` or sets collisions false to prevent phantom blocking.
    - Sets `model:SetAttribute("IsDead", true)` to reject subsequent raycast hits.

---

## 13. Prototype pistol presentation

- To avoid external toolbox dependencies and maintain focus on the vertical slice:
  - **No viewmodel rig needed yet**: Viewmodels and first-person weapon animations belong to future milestones.
  - **Visual feedback**:
    - Optional minimal bullet tracer: A brief, thin beam or laser Part (`0.1` stud thickness, neon material) instantiated on the client or server along the aim direction for 0.05 seconds.
    - Numeric feedback via the bottom-right Ammo UI (`12 / 60`).
    - When reloading, the Ammo UI displays `RELOADING...`.

---

## 14. Prototype zombie representation

- **Streamlined Procedural Rig**:
  - Built programmatically by `src/server/Zombie.luau` on server start.
  - Components:
    - `Model` named `"Zombie"` in `Workspace`.
    - `HumanoidRootPart` (`Size = Vector3.new(2, 2, 1)`, `Transparency = 1`, `CanCollide = false`, `Anchored = false`). Assigned as `Model.PrimaryPart`.
    - `Torso` (`Size = Vector3.new(2, 2, 1)`, `Color = Color3.fromRGB(60, 70, 90)`, `CanCollide = true`, `Anchored = false`). Welded to `HumanoidRootPart` via `WeldConstraint`.
    - `Head` (`Size = Vector3.new(1.25, 1.25, 1.25)`, `Color = Color3.fromRGB(75, 130, 75)`, `CanCollide = true`, `Anchored = false`). Welded to `Torso` via `WeldConstraint`.
    - `Humanoid` (`MaxHealth = 80, Health = 80, WalkSpeed = 12, HipHeight = 2.0`).
  - Spawns at `Vector3.new(0, 3, -35)` (35 studs in front of spawn point).
  - **Why this works reliably**: `Humanoid:MoveTo` only requires an unanchored `HumanoidRootPart` (PrimaryPart), a valid `HipHeight`, and a solid collider part. Using `WeldConstraint` connects the parts rigidly without fragile Motor6D C0/C1 offset calculations.

---

## 15. Implementation order

1. **Shared Configuration**:
   - Create `src/shared/PistolConfig.luau` and `src/shared/ZombieConfig.luau`.
2. **Network Remotes**:
   - Create `src/shared/Remotes.luau`.
   - Implement `Remotes.initServer()` (creates `ReplicatedStorage.Remotes`, `FirePistol`, `ReloadPistol`).
   - Implement `Remotes.getClient()` (waits for `ReplicatedStorage:WaitForChild("Remotes")`).
3. **Server Weapon Authority**:
   - Create `src/server/PistolServer.luau`.
   - Setup player attributes (`PistolMagazine`, `PistolReserve`, `PistolReloading`).
   - Bind `FirePistol.OnServerEvent(player, aimDirection)`: validate, raycast from `Head.Position`, apply damage, decrement ammo attribute.
   - Bind `ReloadPistol.OnServerEvent(player)`: delay, calculate ammo transfer, update attributes.
4. **Client Pistol Input & Controller**:
   - Create `src/client/PistolController.luau` (captures LMB and R, enforces semi-auto, sends `aimDirection`).
5. **Ammo UI**:
   - Create `src/client/AmmoGui.luau` (`ResetOnSpawn = false`, reads and listens to `Player` attributes, displays `Mag / Reserve` or `RELOADING...`).
6. **Prototype Zombie Spawner & Model**:
   - In `src/server/Zombie.luau`, create the 3-part welded zombie model generator and place it into Workspace at `(0, 3, -35)`.
7. **Zombie AI Loop**:
   - In `src/server/Zombie.luau`, implement player detection, `Humanoid:MoveTo` chase, distance checks, attack cooldown, and damage application.
8. **Zombie Death Handling**:
   - Connect `Humanoid.Died` in `Zombie.luau` to halt movement, stop attacks, and disable behavior.
9. **Bootstrap Integration**:
   - Update `src/server/init.server.luau` to initialize `Remotes.initServer()`, `PistolServer`, and `Zombie`.
   - Update `src/client/init.client.luau` to initialize `PistolController` and `AmmoGui`.
10. **Respawn & Reset Handling**:
    - Verify `CharacterAdded` listeners properly reset ammo attributes and reacquire targets.
11. **Static Inspection & Review**:
    - Inspect `git diff`, check Luau syntax, and update `AI/IMPLEMENTATION.md`.

---

## 16. Security / exploit review checklist

Codex must ensure the following security checks are active on the server:
- [ ] **Arbitrary Damage**: Client never sends damage numbers; server applies `PistolConfig.Damage` directly.
- [ ] **Target Spoofing**: Client never sends the target instance; server determines hits via server-side raycasting.
- [ ] **Infinite Ammo**: Server verifies `player:GetAttribute("PistolMagazine") > 0` before firing.
- [ ] **Rapid-Fire Hack**: Server validates `os.clock() - lastShotTimes[player] >= (PistolConfig.FireRate - 0.05)`.
- [ ] **Shoot While Reloading**: Server rejects `FirePistol` if `player:GetAttribute("PistolReloading") == true`.
- [ ] **Origin Teleportation**: Server casts rays starting strictly from `player.Character.Head.Position`.
- [ ] **Input Type Checking**: Server verifies `typeof(aimDirection) == "Vector3"`, values are finite and non-zero.

---

## 17. Risks and edge cases

- **Player Dies While Reloading**:
  - *Risk*: A pending `task.delay` finishes after the player respawns, corrupting ammo counts.
  - *Mitigation*: Store a `reloadToken` or verify `character == player.Character and humanoid.Health > 0` before committing reload.
- **Zombie Attacks Stale Character**:
  - *Risk*: Zombie continues damaging a dead player character or errors on nil `HumanoidRootPart`.
  - *Mitigation*: AI loop always checks `targetHumanoid.Health > 0` and `targetRoot:IsDescendantOf(workspace)` before moving or attacking.
- **Self-Hit Raycast**:
  - *Risk*: The pistol raycast immediately hits the player's own head or accessory parts.
  - *Mitigation*: Set `RaycastParams.FilterDescendantsInstances = { player.Character }` with `FilterType = RaycastFilterType.Exclude`.
- **Duplicate Input Listeners on Respawn**:
  - *Risk*: If client input is bound in `CharacterAdded`, every death doubles the fire rate.
  - *Mitigation*: Bind inputs once at the top level of `PistolController` (executed once in `StarterPlayerScripts`).
- **Shooting a Dead Zombie**:
  - *Risk*: Firing at a dead zombie continues dealing damage or playing hit reactions.
  - *Mitigation*: Raycast hit handler checks `zombieHumanoid.Health > 0`.

---

## 18. Verification plan

### Manual Roblox Studio Test Checklist
1. **Spawn & First Person**:
   - Press Play (F5). Verify camera is in first person, mouse is locked, crosshair is centered, and Ammo UI shows `12 / 60`.
2. **Semi-Auto Firing**:
   - Click LMB once: ammo drops to `11 / 60`.
   - Click and hold LMB: verify only 1 shot fires (no automatic fire).
   - Click rapidly: verify shots respect fire rate (~0.2s minimum gap).
3. **Empty Magazine**:
   - Fire all 12 rounds until Ammo UI shows `0 / 60`.
   - Click LMB: verify pistol cannot fire and ammo remains `0 / 60`.
4. **Reload Behavior**:
   - Press `R`: Ammo UI shows `RELOADING...`.
   - Attempt to click LMB during reload: verify pistol cannot fire.
   - After 1.5s: Ammo UI updates to `12 / 48` (reserve correctly decreased by 12).
   - Press `R` when magazine is full (12/48): verify reload does not start.
5. **Zombie Detection & Chase**:
   - Observe the green zombie model 35 studs away.
   - Walk toward the zombie: confirm it detects the player and runs toward the player (`WalkSpeed = 12`).
6. **Zombie Attack & Player Damage**:
   - Let the zombie reach melee range (~4.5 studs).
   - Confirm zombie deals 15 damage at a 1.2s cadence.
   - Observe player health decreasing in Roblox top-right health bar.
7. **Pistol Hit & Zombie Damage**:
   - Aim crosshair at zombie and fire.
   - Confirm zombie health decreases (verified via Studio Explorer or overhead health indicator).
   - Fire 4 body shots (4 x 25 = 100 damage): confirm zombie dies (`Health = 0`).
8. **Zombie Death**:
   - Confirm dead zombie stops moving and can no longer attack the player.
9. **Player Death & Respawn**:
   - Allow a living zombie to attack until player dies.
   - Confirm zombie stops attacking upon player death.
   - After player respawns:
     - Verify first-person camera and crosshair still work.
     - Verify Ammo UI resets to `12 / 60`.
     - Verify pistol fires and reloads normally.
     - Verify zombie detects the new character.
10. **Output Window**:
    - Verify zero errors or warnings appear in Roblox Studio Output.

### Code / Static Verification
- Run Luau static syntax checks on all modified and newly created files.
- Inspect `git diff` to ensure no unrelated files or unintended deletions occurred.

---

## 19. Scope exclusions

The following systems must **NOT** be created or modified:
- Shotgun, AKM, or secondary firearms.
- Weapon inventory, weapon switching, or weapon dropping.
- Melee combat or player knife.
- First-person viewmodel rigs, 3D gun models, or hands animations.
- Patron boons, upgrade selections, or roguelite progression.
- Wave management, spawn points, or multiple zombie archetypes.
- Complex pathfinding meshes, jump links, or obstacle avoidance.
- Audio overhaul or sound effects beyond minimal testing feedback.
- Map expansion, building interiors, or destructible environments.
- Custom player movement (sprinting, sliding, stamina).

---

## 20. Definition of done

The milestone is complete when:
1. A player spawns in first-person with crosshair and `12 / 60` ammo display.
2. Clicking LMB fires semi-automatic hitscan shots toward the crosshair, decreasing magazine ammo.
3. Pressing `R` reloads the pistol using reserve ammo after a 1.5s delay.
4. A procedural prototype zombie chases the player on the baseplate and attacks within melee range.
5. The pistol damages and kills the zombie; the zombie damages and can kill the player.
6. The entire loop survives player death and respawn without errors or state corruption.
