# Task: Visual Combat Pass + Horde Gameplay Fixes

## Goal

Upgrade the combat prototype from temporary block visuals to imported 3D assets and fix core Horde gameplay issues.

The gameplay must feature permanent zombie pursuit for single-player, spawn separation to eliminate clumping, and auto-reload on empty fire.

The visuals must integrate the imported R15 Zombie rig, FPS Arms, and visible Pistol viewmodel while keeping all gameplay authority strictly on the server.

---

## Gameplay Requirements

### 1. Permanent Zombie Pursuit (Single-Player)
- The game is currently single-player: one player versus the horde.
- Every living zombie must permanently pursue the single living player.
- Distance must NOT prevent target acquisition (remove `DetectionRange`).
- If the player is alive:
  - Zombies continuously navigate toward the player's `HumanoidRootPart` unless within melee `AttackRange`.
- If the player is dead:
  - Zombies halt movement and cease attacks immediately.
- After player respawn:
  - All living zombies automatically reacquire the new Character and resume pursuit.
- Keep `AttackRange` (4.5 studs) for melee strikes.

### 2. Spawn Separation
- Eliminate zombie stacking and overlapping spawns on the Baseplate.
- Replace fixed coordinates with a procedural ring algorithm:
  - Calculate candidate positions around the living player at a configurable radius (`MinSpawnRadius = 55`, `MaxSpawnRadius = 95`).
  - Require candidate distance from player >= `MinPlayerSpawnDistance` (50 studs).
  - Require candidate distance from all living zombies >= `MinZombieSeparation` (12 studs).
  - Make up to `MaxSpawnAttempts` (10) attempts per spawn cycle.
  - If no candidate satisfies separation, skip the spawn for that cycle (do NOT force overlapping spawns).
- Maintain the hard alive zombie cap (15) and minimum spawn interval (1.0s).

### 3. Auto-Reload on Empty Fire
- If the player clicks Left Mouse Button when `PistolMagazine == 0` and is not already reloading:
  - Automatically invoke the normal reload request (`ReloadPistol:FireServer()`).
- Manual reload via `R` key must continue working.
- Both manual and auto-reload must use the exact same authoritative server path.
- Avoid remote spam if the player clicks rapidly while reloading.

---

## Visual Presentation Requirements

### 1. Zombie Visual Replacement (`assets/Zombie.rbxm`)
- Replace the procedural 3-part block rig with a clone of `assets/Zombie.rbxm`.
- Map `assets/` into `ReplicatedStorage.Assets` via `default.project.json`.
- Sanitize the cloned zombie template on the server:
  - Remove/disable foreign AI or health scripts (`NPC`, `Health`, `Ragdoll`, `Maid`, `RigTypes`, `RbxNpcSounds`).
  - Retain visual meshes, Motor6D joints, R15 rig hierarchy, Animator, and animations.
- Existing `Zombie.luau` must retain full authority over health, walkspeed, targeting, pursuit, attacks, attributes (`IsZombie`, `IsDead`), and 3-second corpse cleanup with collision removal.
- Play native locomotion animations (idle/walk) via Animator or sanitized `Animate` script.

### 2. FPS Viewmodel (`assets/Arms.rbxm` + `assets/Pistol.rbxm`)
- Create a client-only first-person viewmodel (`src/client/ViewmodelController.luau`).
- Clone `Arms` and `Pistol` locally from `ReplicatedStorage.Assets`.
- Attach the Pistol model rigidly to the Arms model (via `WeldConstraint` to `PrimaryPart`).
- Position the viewmodel relative to `workspace.CurrentCamera` each rendered frame (`RenderStepped`).
- Configure all viewmodel BaseParts:
  - `CanCollide = false`, `CanTouch = false`, `CanQuery = false` (raycasts ignore viewmodel).
  - `CastShadow = false`, `Massless = true`.
- Centralize camera offset, pistol offset, and scale in `src/client/ViewmodelConfig.luau` for easy tuning in Studio.
- Minimal firing feedback: slight viewmodel recoil kick on LMB.
- Real character visibility: prevent player avatar limbs/accessories from clipping through the camera viewmodel in first person.
- Viewmodel lifecycle: hide/destroy on player death, reconstruct cleanly upon respawn without leaking render connections.

---

## Non-Negotiable Architecture Constraints

- **Gameplay Authority Remains Server-Side**:
  - The viewmodel and pistol model are 100% cosmetic client presentation.
  - Firing validation, hitscan raycasting from player's real Head, ammunition decrement, and damage calculation remain strictly on the server in `PistolServer.luau`.
  - Zombie AI and damage remain strictly on the server in `Zombie.luau`.
- **No Premature Complexity**:
  - Do NOT implement viewmodel procedural sway, walking bobbing, complex IK, or viewmodel inventory frameworks.
  - Do NOT implement secondary weapons, weapon switching, shotgun, AKM, melee, or patron systems.

---

## Acceptance Criteria

1. Every living zombie in the arena pursues the player regardless of distance.
2. Zombies never spawn clustered or overlapping each other (separated by at least 12 studs).
3. Zombies never spawn within 50 studs of the living player.
4. When magazine is 0, clicking LMB initiates reload automatically.
5. Pressing R still reloads when magazine is below 12.
6. The imported R15 zombie model appears in the arena instead of the block rig.
7. Imported zombie plays locomotion animations while moving.
8. Pistol raycasts hit the imported zombie model, dealing 25 damage per shot.
9. Dead zombie parts immediately lose all collisions and raycast query.
10. Dead zombie corpse is destroyed after ~3 seconds.
11. First-person arms and pistol appear in front of the camera.
12. Pistol is rigidly attached to arms and follows camera movement smoothly.
13. Viewmodel does not block raycasts or collide with the world.
14. Real character avatar parts do not clip into viewmodel.
15. Firing produces a subtle viewmodel recoil kick.
16. Player death hides viewmodel; player respawn reconstructs viewmodel exactly once.
17. Living zombies reacquire the player upon respawn and resume pursuit.
18. Studio Output remains free of repeating errors or warnings.
