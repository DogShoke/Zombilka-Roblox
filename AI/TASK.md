# Task: Movement + Horde Polish

## Goal

Polish core gameplay feel and presentation across five targeted systems: freeze zombie corpses in their final death pose (eliminating the standing glitch), create a stable physics collision system where living zombies block players without getting launched, implement a LeftShift sprint system, add procedural walk/sprint viewmodel bobbing while preserving authored animations, and increase horde density and pressure.

---

## Requirements

### 1. Zombie Death Pose Freeze
- When a zombie reaches 0 HP, play `DeathAnimation` once.
- Freeze and hold the corpse on its exact final death frame for the duration of `CorpseCleanupDelay` (3.0s).
- The corpse must NEVER visually snap back to an upright standing or rest pose before destruction.
- Animation loading failures or missing tracks must not crash the server or prevent corpse cleanup.
- Do not implement a full ragdoll system.

### 2. Zombie Collision & Player Blocking
- Living zombies must physically collide with and block player movement (prevent phasing through enemies).
- Living zombies must NOT be launched, pushed, or become physics projectiles upon contact with sprinting players.
- Set all visual R15 body parts of the zombie (`Head`, `Torso`, arms, legs) to `CanCollide = false`.
- Create a single dedicated invisible `ZombieCollider` BasePart welded to `HumanoidRootPart`:
  - `CanCollide = true`, `CanTouch = true`, `CanQuery = false` (server raycasts still hit R15 limbs).
  - Configured with `CustomPhysicalProperties`: high friction (1.0), zero elasticity (0.0), and solid density (2.5) to absorb impulses.
- Use `PhysicsService` collision groups:
  - `Players` collides with `Zombies` = `true` (solid blocking).
  - `Zombies` collides with `Zombies` = `false` (prevents physics ping-ponging and swarm clumping explosions).
  - `Players` collides with `Players` = `false`.
- Ensure server network ownership (`root:SetNetworkOwner(nil)`).
- When a zombie dies, immediately disable `ZombieCollider.CanCollide` so players can smoothly walk over corpses.
- Do NOT anchor living zombies.

### 3. Player Sprint (LeftShift)
- Holding `LeftShift` increases player movement speed from `WalkSpeed = 16` to `SprintSpeed = 24`.
- Releasing `LeftShift` returns `WalkSpeed` to `16`.
- Clean reset upon character death and respawn (spawns at default walk speed).
- Clean handling of window unfocus or menu open.
- Expose sprint state to client systems for viewmodel motion.
- Do NOT implement stamina in this milestone.

### 4. Cosmetic Viewmodel Movement & Sprint Bob
- Keep the authored `PistolIdle` animation (`rbxassetid://105188840604362`); do NOT modify hand poses.
- Add procedural viewmodel motion on top of the existing `CameraOffset`:
  - **Idle**: almost no motion.
  - **Walking**: subtle sinusoidal vertical bounce and horizontal sway matching footstep pace.
  - **Sprinting**: faster, more pronounced bob with an optional subtle lowered weapon offset.
- Motion must be purely cosmetic:
  - Camera CFrame, crosshair position, aim direction, and server hitscan raycasts must NOT be affected.
- All bob frequencies, amplitudes, and offsets must be centralized in `ViewmodelConfig.luau`.

### 5. Horde Density & Escalation Tuning
- Increase horde pressure moderately while respecting R15 server performance:
  - `InitialMaxAlive = 5` (up from 3)
  - `MaximumMaxAlive = 25` (up from 15)
  - `InitialSpawnInterval = 3.0` (down from 4.0)
  - `MinimumSpawnInterval = 0.7` (down from 1.0)
  - `DifficultyStepSeconds = 20` (down from 25)
  - `MaxAliveIncreasePerStep = 2`
  - `SpawnIntervalDecreasePerStep = 0.4`
- Maintain existing 15-stud zombie spawn separation and 50-stud player spawn distance.
- Maintain existing deferred escalation timer that begins strictly when the first living player enters the game.

---

## Non-Negotiable Architecture Constraints

- **Server Authority**: Weapon hitscan, ammo, damage, health, zombie AI, spawner progression, and collision group definitions remain 100% server-authoritative.
- **Cosmetic Independence**: Viewmodel bob and recoil are purely visual client transforms layered atop `CurrentCamera`.
- **Out of Scope**: No stamina, no map redesign, no PathfindingService rewrite, no new weapons, no new zombie types, no multiplayer.

---

## Acceptance Criteria

1. Killing a zombie plays `DeathAnimation`, freezes on the final death frame on the ground, and remains completely dead until cleanly destroyed after ~3 seconds.
2. Zombie corpses NEVER snap back to an upright standing pose.
3. Players cannot walk through living zombies; running into a zombie physically halts/blocks the player.
4. Running or sprinting into a zombie does not launch, fling, or bounce the zombie across the map.
5. Zombies in a horde do not bounce off or push each other into physics explosions.
6. Dying zombies immediately lose collision, allowing players to walk through corpses.
7. Holding LeftShift increases player speed to 24; releasing returns speed to 16.
8. Player death and respawn resets sprint state cleanly without speed glitches.
9. First-person viewmodel plays custom `PistolIdle` stance continuously while stationary.
10. Walking produces light, smooth procedural viewmodel bobbing.
11. Sprinting produces faster, stronger bobbing with a subtle lowered weapon offset.
12. Firing while moving or sprinting still applies recoil kick and hits accurately on server raycasts.
13. Horde starts with 5 zombies and scales up to 25 zombies over ~3.5 minutes with spawn interval reducing to 0.7s.
14. Roblox Studio Output remains free of errors and warnings.
