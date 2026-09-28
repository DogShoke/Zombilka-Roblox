# Implementation

## Summary

Phase A only: replaced the old character-based R15 arms and separately cloned pistol with one client-only `FpsGlock` viewmodel. Connected Idle, Shoot, and Reload animation playback while keeping the existing camera, crosshair, pistol gameplay, sprint, bob, zombies, and Horde systems.

## Files changed

- `src/client/ViewmodelConfig.luau` — updated `CameraOffset` to `CFrame.new(0.15, -0.95, -1.3) * CFrame.Angles(0, math.rad(-90), 0)` to properly align the FBX rig's shoulder origin and -90 deg Y orientation with the Roblox camera view frustum.
- `src/client/ViewmodelController.luau` — replaced character cloning with `FpsGlock` viewmodel; applied bobbing and recoil in camera space prior to `CameraOffset`; added `viewmodel:PivotTo` for synchronous part movement.
- `src/server/Zombie.luau` — ensured all non-root BaseParts explicitly retain `Transparency = 0`.
- `AI/IMPLEMENTATION.md` — updated with root cause analysis and resolution.

No source files were created in this pass. The developer-provided `assets/FpsGlock.rbxm` is currently untracked and must be included in the Phase A Git checkpoint for a clean clone. `default.project.json` already maps the `assets/` directory to `ReplicatedStorage.Assets`, so the RBXM maps to `ReplicatedStorage.Assets.FpsGlock` without a JSON edit. `assets/Pistol.rbxm` remains as a backup and is not used by the runtime viewmodel. No Phase B files or server combat code were changed.

## Inspected asset and runtime hierarchy

Binary inspection of the actual `assets/FpsGlock.rbxm` found one Model named `FpsGlock` with 171 instances. Its core hierarchy is:

```text
workspace.CurrentCamera
└── FpsViewmodel (clone of ReplicatedStorage.Assets.FpsGlock)
    ├── RootPart (Part; PrimaryPart; anchored at runtime)
    │   ├── UpperArm.R.001 → LowerArm.R.001 → Hand.R.001 → weapon/finger Bones
    │   └── UpperArm.L → LowerArm.L → Hand.L → finger Bones
    ├── ArmModel (MeshPart; ArmModelMotor6D links RootPart to ArmModel)
    ├── Glock19 (MeshPart; Glock19Motor6D links RootPart to Glock19)
    ├── AnimationController
    │   ├── Animator (created at runtime; absent from the saved RBXM)
    │   ├── Idle, Shoot, Reload (runtime Animation objects)
    ├── InitialPoses (Folder with 132 CFrameValues)
    └── AnimSaves (ObjectValue)
```

The controller validates `RootPart`, both MeshParts, both Motor6D connections, and the imported `AnimationController` before using the clone. All BaseParts become non-colliding, non-touching, non-queryable, shadowless, massless, and locally visible; `RootPart` is hidden and is the only anchored part. The imported rig and its Bones are not rescaled or repositioned individually.

## Animation IDs and playback

- Idle: `rbxassetid://105345463794666` — looped at Idle priority and started when the viewmodel is built. It stays active beneath Action-priority animations.
- Shoot: `rbxassetid://128130246447749` — non-looped at Action priority. The existing `PistolController` calls `playFireFeedback()` after its validated local fire request. The same single track is stopped and replayed for rapid shots; procedural recoil remains cosmetic.
- Reload: `rbxassetid://130294402000435` — non-looped at Action priority. The existing server-owned `PistolReloading` Player Attribute triggers it for manual and automatic reloads. If a viewmodel appears during an active reload, it starts the visual reload then too.
- Grip: `rbxassetid://93225329241822` and Inspect: `rbxassetid://115095786328194` are stored in config for later use and have no Phase A input or playback.

The reload track starts at speed `track.Length / PistolConfig.ReloadDuration` when Length is available; `ReloadDuration` remains 1.5 seconds. If Length is initially zero, playback starts at normal speed and a bounded task adjusts to the same ratio once Length loads. Animation state never grants ammo or changes server timing.

## Old presentation removed and camera lifecycle

- Removed runtime R15 character cloning, appearance wait, retained R15 joint tables, synthetic RightGrip, separate `Pistol.rbxm` clone, old PistolIdle ID, and all old clothing/body-copy logic. No fallback hand pose is generated.
- The real Character is still hidden locally with `LocalTransparencyModifier = 1`, including parts added later. The imported viewmodel follows `CurrentCamera` each render step through `CameraOffset * bobOffset * recoilOffset`; the camera and server aim vector are not changed.
- A single `CharacterAdded` listener and one named render binding are installed. On death or respawn, tracks stop, the clone is destroyed, bob/recoil reset, and delayed reload adjustment is invalidated. Construction checks a generation token before and after track loading so an old character cannot leave stale tracks or a stale viewmodel. The controller also removes an old `Viewmodel` child if present during construction.

## Failure behavior

- Missing or malformed FpsGlock, missing camera, clone failure, or animation load/play failure warns without blocking `PistolController` or server shooting. Asset and camera waits are bounded.
- Reload animation speed adjustment is cosmetic and protected; if Length never becomes available, gameplay reload still completes on the server.

## Verification performed

- Read `AGENTS.md`, `AI/PROJECT.md`, `AI/TASK.md`, `AI/PLAN.md`, `AI/IMPLEMENTATION.md`, and `default.project.json` before editing; inspected the current client implementation and actual `assets/FpsGlock.rbxm` binary hierarchy and joint references.
- Inspected source changes, searched for old runtime viewmodel references, checked the Rojo asset mapping, and ran `git diff --check`.
- Roblox Studio Play testing was not performed. Rojo, Luau, and Selene command-line tools were unavailable here.

## Deviations from PLAN.md

- The saved RBXM has an `AnimationController` but no `Animator`; the controller creates only that missing `Animator` at runtime.
- The ready-made asset was already imported and published by the developer, so no FBX import or animation publishing was performed in this pass.
- The existing `PistolController` already signals Shoot through `playFireFeedback()`, and the existing `PistolReloading` attribute signals Reload; no second input controller was added.

## Root cause analysis of Phase A test failure
- **Missing Hands & Floating Weapon**: The previous implementation retained `CameraOffset = CFrame.new(0.35, -1.35, -0.2)` from the old R15 character viewmodel. In `assets/FpsGlock.rbxm`, `RootPart` is at the rig's origin where shoulders are at `Y = 0`, but the rig is modeled facing +X (rotated 90 degrees relative to camera look direction -Z) with shoulders at `X ≈ 2.536`. Pushing `RootPart` down by 1.35 studs sank the entire viewmodel below the camera frustum and faced it sideways, causing only shoulder tips to clip into the bottom and the Glock to hover on the far left. Rotating by `math.rad(-90)` around Y and shifting `CFrame.new(0.15, -0.95, -1.3)` brings the shoulders and two-handed grip directly in front of the camera view.
- **Zombie Visibility**: Online Roblox assets (such as zombie mesh parts and sounds) experienced HTTP timeouts during Studio startup (`HttpError: Timeout`). To prevent invisible zombie bodies, `Zombie.luau` now explicitly forces `Transparency = 0` on all non-root BaseParts.

## Known limitations

- If Reload Length becomes available after playback begins, the speed is corrected then; the visual finish can be slightly late relative to the fixed 1.5-second gameplay reload. Gameplay remains authoritative.
- Visual animation alignment and fine camera adjustments can be tweaked via `CameraOffset` in `ViewmodelConfig.luau`.

## Roblox Studio runtime checklist

1. Sync the project in a clean Studio place. Confirm `ReplicatedStorage.Assets.FpsGlock` exists and contains `RootPart`, `ArmModel`, `Glock19`, both Motor6Ds, and `AnimationController`.
2. Start Play. Confirm exactly one `Workspace.CurrentCamera.FpsViewmodel`, with a runtime `AnimationController.Animator`, visible arms and Glock, no old R15 arm viewmodel, and no Output errors.
3. Stand still and look around. Confirm Idle loops continuously and the complete rig follows the camera without clipping; tune only `ViewmodelConfig.CameraOffset` if needed.
4. Fire single and rapid LMB shots. Confirm Shoot replays cleanly, recoil remains visible, and ammo/server zombie damage still behave as before.
5. Press R with a partial magazine and empty the magazine to trigger auto-reload. Confirm Reload plays for about 1.5 seconds, Idle remains underneath, and ammo refills only when server reload completes.
6. Walk, sprint, open the menu, and return. Confirm existing bob, sprint speed, crosshair, first-person camera, and aim remain correct.
7. Die and respawn repeatedly. Confirm the old model and tracks disappear and exactly one fresh FpsViewmodel appears each time, without warnings or duplicate render/input behavior.
