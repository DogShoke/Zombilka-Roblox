# Implementation

## Summary

- Added imported Zombie, Arms, and Pistol visuals while preserving the server-authoritative pistol, zombie attacks, corpse cleanup, and horde escalation.
- Zombies now pursue a living player at any distance. Horde spawns use a separated procedural ring. Clicking with an empty magazine requests the existing server reload.
- Added a local camera viewmodel with bone-following pistol placement and cosmetic recoil. Roblox Studio runtime testing remains required.

## Files created

- `src/client/ViewmodelConfig.luau` — camera, right-palm pistol, and recoil transforms.
- `src/client/ViewmodelController.luau` — local Arms/Pistol clones, part isolation, camera update, avatar hiding, recoil, and respawn lifecycle.

## Files modified

- `default.project.json` — maps `assets/` to `ReplicatedStorage.Assets`.
- `src/shared/ZombieConfig.luau` — removes detection distance.
- `src/shared/HordeConfig.luau` — replaces fixed points with ring radius, separation, attempt, and arena parameters.
- `src/server/Zombie.luau` — clones and sanitizes the imported rig, plays locomotion tracks, and pursues without a range limit.
- `src/server/ZombieSpawner.luau` — selects separated procedural spawn candidates.
- `src/client/PistolController.luau` — requests reload on empty click and triggers cosmetic viewmodel recoil.
- `src/client/init.client.luau` — starts the viewmodel controller.
- `AI/IMPLEMENTATION.md` — records the current milestone.

## Rojo asset mapping

- `default.project.json` maps `assets/Zombie.rbxm`, `assets/Pistol.rbxm`, and `assets/Arms.rbxm` under `ReplicatedStorage.Assets` as `Zombie`, `Pistol`, and `Arms`.
- Server clones only Zombie; client clones Arms and Pistol. No manually inserted Workspace models are required.

## Inspected asset structures

- Binary `.rbxm` contents were inspected directly. Zombie is one Model with 15 MeshParts, a HumanoidRootPart, R15 Motor6D joints, a Humanoid with Animator, and an `Animations` folder. Idle and walk/run Animation objects are nested under its `Animate` Script.
- Zombie also contains foreign `NPC`, `Health`, `Animate`, and `RbxNpcSounds` Scripts; `Maid`, `Ragdoll`, and `RigTypes` ModuleScripts; a `Configuration`; and an `AlignOrientation` constraint.
- Arms is one Model with one skinned `armsmesh`, an AnimationController/Animator, and 39 Bones. `R_palm` is present under the right wrist. There is no separate right-hand Attachment or BasePart.
- Pistol is a Model with 31 MeshParts, including direct child `Body`, plus nested visual Models. It contains no WeldConstraint or Motor6D joints.

## Zombie sanitization and animation

- Before the clone enters Workspace, all Script, LocalScript, and ModuleScript descendants are destroyed, including `Animate`. Its Animation descendants are moved into the preserved `Animations` folder first; `Idle`, `Walk`, and `Run` are identified there.
- The foreign `Configuration` and root `AlignOrientation` are removed so neither imported settings nor orientation constraints compete with our AI. R15 parts, Motor6Ds, attachments, Humanoid, Animator, meshes, and Animation objects remain.
- Our server controller sets health and walkspeed, then loads available idle/walk tracks through the preserved Animator after the clone enters Workspace. Missing or unloadable animations are skipped without preventing movement. The tracks stop on death.
- Existing `IsZombie`/`IsDead` attributes, attack cooldown, server damage, alive-count callback, collision removal, and three-second corpse destruction remain.

## Permanent targeting

- Removed `DetectionRange`. Each living zombie chooses the nearest living Character with a valid HumanoidRootPart and calls `Humanoid:MoveTo` regardless of distance.
- With no living player it stops moving and attacking; after respawn the next AI tick finds the new Character.

## Spawn separation

- HordeConfig defines a 55–95 stud ring, 50-stud player buffer, 12-stud living-zombie buffer, 10 attempts, and a 220-stud arena boundary.
- The spawner samples a candidate around the player, checks all living players and tagged living zombies, and skips the cycle if no safe candidate is found.
- The existing first-player timer gate, alive-count registration, 15-zombie hard cap, and one-second minimum spawn interval remain in place.

## Auto reload

- On LMB with `PistolMagazine == 0`, the client sends the existing `ReloadPistol` request when not already reloading. R uses the same request helper.
- A short local request throttle limits rapid-click traffic while attributes replicate. The server remains authoritative for reload acceptance and timing.
- Valid shots still send only camera LookVector to `FirePistol`; cosmetic recoil runs afterward and does not affect server aim, ray origin, or damage.

## Arms/Pistol attachment and viewmodel lifecycle

- The actual Arms asset has a `R_palm` Bone. Each camera frame, Arms follows the camera and the entire anchored Pistol Model pivots to `R_palm.TransformedWorldCFrame * ViewmodelConfig.PistolOffset`. This follows future hand-bone animation without attaching gameplay physics to the Bone.
- Because the Pistol asset has no internal joints, all 31 MeshParts are anchored locally and move rigidly together via `Model:PivotTo`. No scale is applied to either source asset.
- Every viewmodel BasePart has collision, touch, query, and shadow disabled. The viewmodel is local to CurrentCamera; server raycasts still originate at the real Character Head.
- One named render binding updates the model and decays a small visual recoil offset. Death destroys the viewmodel; CharacterAdded rebuilds it once, with stale-character checks and prior connection cleanup. Current Character BaseParts are hidden locally to prevent clipping.

## Manual Studio tuning

- The native orientation and size of the imported Arms/Pistol visuals must be checked in Studio. Adjust only `ViewmodelConfig.CameraOffset` and `PistolOffset` if grip or framing is off; source asset scale is unchanged.
- Confirm imported animation IDs are playable by this experience. If access fails, zombie movement continues without those tracks.

## Verification performed

- Read current task, plan, project context, existing source, Rojo mapping, and inspected all three binary `.rbxm` hierarchies before editing.
- Confirmed `R_palm` Bone, Pistol.Body, Zombie HumanoidRootPart/Humanoid/Animator/Motor6Ds, foreign scripts, and idle/walk/run Animation objects in the assets.
- Inspected changed source and Git diff; searched for old detection and fixed-spawn references, checked client-only viewmodel flags, script sanitization, remote contract, death/respawn guards, and server ownership.
- Parsed `default.project.json` and ran `git diff --check`. Rojo/Luau CLI and Roblox Studio runtime checks were not available in this environment.

## Deviations from PLAN.md

- Deleted imported `Animate` as required by the task clarification and moved its Animation objects to the existing folder before deletion. Only our server code drives idle/walk tracks.
- Used per-frame `R_palm` Bone placement rather than an `armsmesh` WeldConstraint. The inspected Arms asset has a suitable animated hand bone and the Pistol asset has no internal joints. Anchored Model pivots keep the visual parts rigid and follow future bone animation.
- Omitted speculative ArmsScale/PistolScale values because the source asset scale was left unchanged pending Studio inspection.
- Removed the imported `AlignOrientation` with foreign scripts because it can compete with Humanoid AutoRotate; the R15 Motor6D rig remains intact.

## Known limitations

- Imported asset orientation, animation permissions, visible grip alignment, zombie locomotion, and viewmodel framing require Roblox Studio runtime verification.
- Zombies still use direct `Humanoid:MoveTo` on a flat arena; advanced navigation is outside this milestone.

## Roblox Studio verification checklist

1. Sync from a clean clone. Confirm `ReplicatedStorage.Assets` contains exactly the three imported templates and runtime Zombie clones contain no Script, LocalScript, or ModuleScript descendants.
2. Spawn and verify first person, crosshair, ammo UI, visible Arms/Pistol, one Viewmodel under CurrentCamera, and no local avatar clipping or physical/raycast interference.
3. Fire 12 shots; verify server ammo/damage, one shot per click, cosmetic recoil, and LMB auto-reload at zero. Confirm R manual reload remains functional and rapid empty clicks do not flood remotes.
4. Inspect a runtime Zombie: verify imported R15 visuals, preserved Motor6Ds/Animator, idle/walk playback, 80 HP, and no foreign Animate/NPC logic. If tracks fail, verify movement still works.
5. Run across the Baseplate; verify every living zombie pursues regardless of distance. Inspect spawn positions for at least 50 studs from players and 12 studs from living zombies, with no forced overlapping spawn.
6. Kill zombies: verify 25 damage per hit, immediate AI stop and collision/query removal, alive-count replenishment, and corpse destruction after about three seconds. Confirm horde escalation and the hard 15-alive cap still work.
7. Die and respawn repeatedly: verify viewmodel removal/recreation without duplicates, pistol input, FPS systems, zombie reacquisition, and no duplicate render/spawner loops. Inspect Studio Output for repeated errors or warnings.
