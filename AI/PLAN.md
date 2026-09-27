# Plan: First FPS Foundation

## Current project assessment

The project is currently a freshly initialized Rojo 7.7.0 workspace synchronized with Roblox Studio:
- `default.project.json` defines standard mappings:
  - `src/shared` -> `ReplicatedStorage.Shared`
  - `src/server` -> `ServerScriptService.Server`
  - `src/client` -> `StarterPlayer.StarterPlayerScripts.Client`
  - Minimal `Workspace` with a default `Baseplate`, `Lighting`, and `SoundService`.
- Existing code in `src/` consists entirely of starter placeholders:
  - `src/client/init.client.luau` (single test `print`)
  - `src/server/init.server.luau` and `src/server/Test.server.luau` (placeholder prints)
  - `src/shared/Hello.luau` (placeholder function)
- No gameplay, camera, movement, or UI systems currently exist.
- Git working tree is clean.

## Recommended approach

Use Roblox's native first-person camera mode rather than developing a custom camera controller:
1. **Roblox-native camera**: Configure `Player.CameraMode = Enum.CameraMode.LockFirstPerson` (and set `CameraMinZoomDistance = 0.5` / `CameraMaxZoomDistance = 0.5`). Roblox's built-in `CameraModule` automatically locks the mouse to center, hides the mouse cursor, handles mouse delta rotation with pitch clamping, keeps the character oriented with camera yaw, and integrates with the Roblox Esc menu.
2. **Programmatic crosshair module**: Create a modular Luau component (`src/client/Crosshair.luau`) that builds a lightweight `ScreenGui` containing a clean center reticle. Setting `ScreenGui.ResetOnSpawn = false` and `ScreenGui.IgnoreGuiInset = true` guarantees exact screen-center alignment and seamless persistence across respawns without relying on binary asset files.
3. **Client-only scope**: Keep all changes strictly on the client (`src/client`). Do not add server-side scripts or RemoteEvents for this task, as camera mode and crosshair presentation are purely local client concerns.

## Existing systems involved

- `default.project.json`: Rojo project definition mapping `src/client` into `StarterPlayer.StarterPlayerScripts.Client`.
- `src/client/init.client.luau`: Client entry point script executed by Roblox when the local player connects.

## Files to modify

- `src/client/init.client.luau`:
  - Remove placeholder print.
  - Enforce `LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson`.
  - Clamp `LocalPlayer.CameraMinZoomDistance` and `LocalPlayer.CameraMaxZoomDistance` to `0.5`.
  - Require and initialize `Crosshair.luau`.
- `default.project.json` (recommended):
  - Add `$properties` to `StarterPlayer`:
    ```json
    "StarterPlayer": {
      "$properties": {
        "CameraMode": "LockFirstPerson",
        "CameraMinZoomDistance": 0.5,
        "CameraMaxZoomDistance": 0.5
      },
      "StarterPlayerScripts": {
        "Client": {
          "$path": "src/client"
        }
      }
    }
    ```
  - This ensures Roblox Studio place defaults to first person at engine startup, preventing any single-frame camera transition before client scripts execute.

## Files to create

- `src/client/Crosshair.luau`:
  - Client module providing `Crosshair.mount()` (or `Crosshair.init()`).
  - Constructs and mounts a `ScreenGui` containing a minimalist, high-contrast center crosshair.
  - Idempotent: cleans up or ignores pre-existing instances to support Rojo live reloading cleanly.

## Architecture

```
[StarterPlayer (default.project.json: LockFirstPerson)]
       │
       ▼ (Player Joins)
[StarterPlayerScripts.Client (init.client.luau)]
       │
       ├──► Sets LocalPlayer.CameraMode = LockFirstPerson
       │    Sets LocalPlayer Zoom min/max = 0.5
       │    (Roblox built-in CameraModule handles mouse lock, cursor hide, look rotation)
       │
       └──► Calls Crosshair.mount()
                 │
                 ▼
            [PlayerGui / CrosshairGui]
            - ResetOnSpawn = false
            - IgnoreGuiInset = true
            - Center Reticle / Dot
```

- **Execution Flow**:
  1. `init.client.luau` runs once when the client connects.
  2. It enforces first-person camera properties on `Players.LocalPlayer`.
  3. It requires `Crosshair` and calls `Crosshair.mount()`.
  4. `Crosshair.mount()` checks if `PlayerGui:FindFirstChild("CrosshairGui")` exists. If not, it creates a `ScreenGui` with `ResetOnSpawn = false` and `IgnoreGuiInset = true`, attaches a centered frame with reticle lines/dot, and parents it to `PlayerGui`.

## Client/server responsibilities

- **Client (`src/client`)**:
  - Exclusively responsible for this milestone.
  - Controls local camera zoom/mode settings.
  - Instantiates and displays the local crosshair GUI.
- **Server (`src/server`)**:
  - No code or modifications needed.
  - While combat authority (damage, bullets, health) will reside on the server in future milestones, camera locking and HUD rendering have no server dependencies.

## First-person camera

- **Approach**: Built-in Roblox `Enum.CameraMode.LockFirstPerson`.
- **Reasoning**:
  - **Zero boilerplate**: Custom camera controllers require manual mouse delta binding via `ContextActionService`/`UserInputService`, manual `workspace.CurrentCamera` CFrame calculations, custom pitch clamping, character orientation alignment, and gamepad/mobile fallbacks.
  - **Native stability**: Roblox's built-in `CameraModule` handles character lifecycle, occlusion, collision checks with the environment, and respects user camera sensitivity settings from the Roblox core menu.
  - **Respawn resiliency**: Built-in camera automatically binds to newly spawned character heads without custom event listeners.

## Mouse / cursor behavior

- In `Enum.CameraMode.LockFirstPerson`, Roblox's built-in camera system sets `UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter` and hides the system cursor.
- When the user presses `Esc` to view the Roblox pause menu, Roblox core scripts handle releasing the mouse and restoring cursor visibility automatically.
- Do NOT implement a custom loop or manual `MouseBehavior` locking script, as this conflicts with Roblox's internal `CameraModule` and causes cursor stutter or menu locking bugs.

## Crosshair

- **Implementation**: Pure Luau UI constructed in `src/client/Crosshair.luau`.
- **Key Properties**:
  - `ScreenGui.Name = "CrosshairGui"`
  - `ScreenGui.ResetOnSpawn = false` (essential: prevents GUI destruction when the character dies).
  - `ScreenGui.IgnoreGuiInset = true` (essential: aligns `UDim2.fromScale(0.5, 0.5)` with true viewport center and camera forward ray, bypassing the 36-58px top bar offset).
  - `ScreenGui.DisplayOrder = 10`
- **Visual Design**:
  - Container `Frame`: `AnchorPoint = Vector2.new(0.5, 0.5)`, `Position = UDim2.fromScale(0.5, 0.5)`, `Size = UDim2.fromOffset(24, 24)`, `BackgroundTransparency = 1`.
  - Reticle options (minimalist FPS style):
    - A center dot (e.g., 2x2 or 4x4 px) with a subtle dark outline / `UIStroke` so it remains visible against both bright and dark backgrounds.
    - Or 4 small crosshair bars (top, bottom, left, right: e.g., 2x6 px with a 4px gap) with dark outlines.
  - Set `Active = false` and `Selectable = false` on all GUI elements so they never consume input or block clicks.

## Respawn behavior

- `StarterPlayerScripts` executes only once per player session.
- `Player.CameraMode` is stored on the `Player` instance in `Players`, persisting across character deaths and respawns.
- Roblox's `CameraModule` automatically reattaches to the new character upon respawn.
- `ScreenGui.ResetOnSpawn = false` ensures `CrosshairGui` is preserved across deaths, preventing flicker or destruction.
- No `CharacterAdded` re-initialization logic is necessary, eliminating race conditions.

## Implementation steps

1. **Configure StarterPlayer properties (recommended)**:
   - In `default.project.json`, add `$properties` to `StarterPlayer` defining `"CameraMode": "LockFirstPerson"`, `"CameraMinZoomDistance": 0.5`, `"CameraMaxZoomDistance": 0.5`.
2. **Create Crosshair module**:
   - Create `src/client/Crosshair.luau`.
   - Implement idempotent mount logic (`PlayerGui:FindFirstChild("CrosshairGui")`).
   - Create `ScreenGui` with `ResetOnSpawn = false`, `IgnoreGuiInset = true`.
   - Construct centered reticle elements with high-contrast outlines and `Active = false`.
   - Return `{ mount = mount }` interface.
3. **Update Client Entry Point**:
   - In `src/client/init.client.luau`, require `Crosshair`.
   - Set `LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson`.
   - Set `LocalPlayer.CameraMinZoomDistance = 0.5` and `LocalPlayer.CameraMaxZoomDistance = 0.5`.
   - Call `Crosshair.mount()`.
4. **Keep Other Systems Untouched**:
   - Leave `src/server/` and `src/shared/` untouched.
5. **Verify syntax & diff**:
   - Ensure clean Luau syntax without linter warnings.
   - Inspect git diff against `master`.
6. **Update implementation log**:
   - Fill in `AI/IMPLEMENTATION.md` detailing changes and verification steps.

## Risks / edge cases

- **TopBar Inset Alignment**:
  - *Risk*: If `IgnoreGuiInset` is left `false`, the crosshair will be centered relative to the area below Roblox's top bar rather than the true center of the screen, creating an aim offset.
  - *Mitigation*: Explicitly set `IgnoreGuiInset = true` on `ScreenGui`.
- **Crosshair Disappearing on Death**:
  - *Risk*: Default `ScreenGui.ResetOnSpawn` is `true`. Because the GUI is instantiated from `StarterPlayerScripts` into `PlayerGui`, Roblox would destroy it upon first death and never recreate it.
  - *Mitigation*: Explicitly set `ResetOnSpawn = false`.
- **Rojo Live Reload Duplicate GUIs**:
  - *Risk*: Editing client files while Rojo is connected can re-run `init.client.luau`, creating duplicate crosshair instances in `PlayerGui`.
  - *Mitigation*: Check `PlayerGui:FindFirstChild("CrosshairGui")` before creation or destroy the prior instance.
- **Input Interception**:
  - *Risk*: If GUI frames have `Active = true`, clicks intended for future weapon firing or world interaction may be swallowed.
  - *Mitigation*: Ensure all UI frames have `Active = false`.
- **Studio Focus**:
  - *Risk*: In Roblox Studio Play mode, mouse lock might not capture until the viewport is clicked once.
  - *Mitigation*: Note this in verification steps as expected Studio testing behavior.

## Verification

### Manual Roblox Studio Verification Checklist
1. **Initial Spawn**:
   - Press **Play** (F5) in Roblox Studio.
   - Click inside the game window.
   - Verify camera zooms directly into the character's head in first person.
2. **Mouse Look & Cursor**:
   - Move mouse across the pad; confirm the camera rotates smoothly in pitch (vertical) and yaw (horizontal).
   - Confirm the default mouse cursor is hidden.
   - Confirm vertical look clamps appropriately and does not invert or roll.
3. **Crosshair Alignment**:
   - Confirm the crosshair is visible in the dead center of the screen.
   - Test aiming against dark surfaces (e.g. shadows) and bright surfaces (e.g. skybox); confirm reticle remains easily legible.
4. **Character Movement**:
   - Use `W`, `A`, `S`, `D` to walk and `Space` to jump.
   - Verify character moves relative to camera direction without camera clipping or detachment.
5. **Escape Menu & Cursor Release**:
   - Press `Esc` to open the Roblox game menu.
   - Confirm mouse cursor unlocks and becomes visible.
   - Press `Esc` to resume; confirm mouse locks back to center and cursor hides.
6. **Respawn Persistence**:
   - Open Esc menu and click **Reset Character** (or set `Humanoid.Health = 0` via developer console).
   - Upon respawning, verify:
     - Player remains immediately in first-person camera mode.
     - Mouse cursor re-locks.
     - Crosshair remains visible at center screen.
     - No duplicate crosshair instances exist in `PlayerGui`.

### Code / Static Verification
- Run available Luau linters or check syntax.
- Run `git diff` to confirm only `AI/PLAN.md`, `default.project.json`, `src/client/init.client.luau`, and `src/client/Crosshair.luau` are touched.

## Scope exclusions

The following systems must **NOT** be touched or implemented during this task:
- Weapons, firearms, bullets, hitscan, or projectile systems.
- Weapon animations, viewmodels, or custom arms.
- Ammunition, reloading, or weapon switching.
- Custom movement controllers (sprinting, sliding, dashing, stamina).
- Enemy AI, zombies, health damage, or wave spawning.
- Patron boons, upgrade menus, or roguelite systems.
- Server replication, damage validation, or RemoteEvents.
- Extended HUD elements (health bars, ammo counters, maps).
- Audio assets, visual particle effects, or map geometry.
