# Implementation

## Summary

- Added solid player-versus-zombie blocking through collision groups and one dedicated collider per living zombie.
- Added a final-frame death animation freeze with corpse destruction scheduled independently at death.
- Added LeftShift sprint and cosmetic walk/sprint viewmodel bob without changing camera aim, pistol gameplay, or the authored PistolIdle animation (`rbxassetid://105188840604362`).
- Tuned horde limits, spawn interval, and 15-stud zombie separation.

## Files created

- `src/shared/CollisionGroups.luau`
- `src/client/SprintController.luau`

## Files modified

- `src/shared/HordeConfig.luau`
- `src/server/init.server.luau`
- `src/server/PistolServer.luau`
- `src/server/Zombie.luau`
- `src/client/init.client.luau`
- `src/client/ViewmodelConfig.luau`
- `src/client/ViewmodelController.luau`
- `AI/IMPLEMENTATION.md`

## Collision groups and player assignment

- Server startup registers `Players` and `Zombies` before starting pistol and zombie systems. Players collide with Zombies and Default; Zombies collide with Default but not other Zombies; Players do not collide with other Players.
- On each `CharacterAdded`, `PistolServer` assigns `Players` to **every** existing character `BasePart` via `GetDescendants()` and connects `DescendantAdded` for later limbs and accessory Handles. The previous character listener is disconnected on respawn and player removal. Pistol shooting, ammo, and reload logic are otherwise unchanged.

## ZombieCollider and death lifecycle

- Every visual zombie `BasePart`, including root and R15 limbs, is non-colliding and non-touching but queryable for server hitscan. A separate invisible 2.2 × 4.8 × 1.8 `ZombieCollider` is welded to `HumanoidRootPart`, uses the `Zombies` group, collides while alive, is excluded from raycasts, and has density 2.5, friction 1.0, and elasticity 0.0. Living zombies remain unanchored; the root retains server network ownership.
- Death marks the model dead, disables collider and other corpse collision/query immediately, and calls the existing Horde death callback once. `CorpseCleanupDelay` destruction is scheduled immediately and does not wait for animation loading, playback, pose freezing, or anchoring.
- `DeathAnimation` plays once at Action4 priority. The pose task waits briefly for track length, seeks to about 0.08 seconds before its end, pauses with `AdjustSpeed(0)`, then anchors corpse parts after the pose updates. If the track is absent, its length stays zero, or the pose task errors, the task still anchors the corpse; the independent destroy timer still runs.

## Sprint lifecycle and viewmodel bob

- `SprintController` uses LeftShift to set the local living Humanoid speed to 24 while held and 16 when released. It resets on death, respawn, menu open, and window focus loss; processed input such as chat does not start sprint. The controller exposes `isSprinting()` to the viewmodel.
- `ViewmodelController` calculates horizontal movement from the current character, adds sinusoidal walk/sprint sway and bounce plus a sprint-lowered offset, and smooths the result. It multiplies the cosmetic offset between `CameraOffset` and existing recoil. Bob state resets when the viewmodel is destroyed. The camera, crosshair, fire direction, server raycast, and authored hand pose are untouched.

## Horde tuning

- `InitialMaxAlive = 5`, `MaximumMaxAlive = 25`, `InitialSpawnInterval = 3.0`, `MinimumSpawnInterval = 0.7`, `DifficultyStepSeconds = 20`, `MaxAliveIncreasePerStep = 2`, `SpawnIntervalDecreasePerStep = 0.4`, `MinZombieSeparation = 15`, `MinPlayerSpawnDistance = 50`.
- Existing spawn ring, attempt limit, first-living-player start gate, alive-count logic, and `ZombieSpawner.luau` remain unchanged.

## Verification performed

- Read the current task, plan, project instructions, prior implementation report, Rojo mapping, and relevant client/server/shared source before editing.
- Inspected the full working-tree Git diff and ran `git diff --check` successfully. The working tree already included changes to `AI/TASK.md`, `AI/PLAN.md`, and deletion of `assets/Arms.rbxm`; this pass did not edit those files.
- Checked the server startup order, all-BasePart player assignment, collider query/collision flags, death callback and independent destroy scheduling, sprint reset paths, cosmetic-only bob transform, horde values, and unchanged PistolIdle ID in source.
- Rojo, Luau, Selene, and Stylua command-line tools were not available in this shell. Roblox Studio runtime testing was not performed.

## Deviations from PLAN.md

- Assigned **all** player character BaseParts, including late accessory Handles, to `Players` instead of the plan's four named body parts, per the task correction.
- Set `MinZombieSeparation = 15` instead of the plan's 12, per the task correction.
- Scheduled corpse destruction before animation/callback work so cleanup remains independent even if pose freezing fails, per the task correction.
- Used a registration check before adding collision groups to avoid warnings when groups already exist in Studio.

## Known limitations

- Physical blocking, resistance to pushing, death pose appearance, animation permissions, and 25-zombie performance require Roblox Studio testing. The last frame is held near the end of the animation as the plan specifies; an unavailable animation falls back to anchoring the current corpse pose.
- Sprint speed is set on the local player's Humanoid as specified by the plan; this milestone adds no stamina or movement anti-cheat.

## Ordered Roblox Studio test checklist

1. Start Play. Confirm five initial zombies and no Output errors; inspect `ZombieCollider` and visual R15 part collision/query properties.
2. Walk and sprint into living zombies. Confirm blocking without zombie fling and no zombie-versus-zombie physics explosions.
3. Kill a zombie in contact range. Confirm immediate corpse passthrough, death animation ending in a held pose, and destruction after about three seconds.
4. Hold/release LeftShift and inspect Humanoid.WalkSpeed (24/16). Repeat after opening the menu, losing focus, dying, and respawning.
5. Stand, walk, and sprint. Confirm PistolIdle remains active, bob becomes stronger during sprint, and the pistol lowers slightly. Fire while moving and verify crosshair/aim/hits stay accurate.
6. Survive long enough to observe escalation toward 25 alive and 0.7-second minimum spawn interval; check 15-stud zombie spawn spacing and no spawning before a living player appears.
