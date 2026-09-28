# Task: FPS Rig Migration + Headshots + Talent Prototype

## Goal

Execute a two-phase milestone that:
1. **Phase A**: Migrates the client-side FPS presentation to the ready-made animated Glock FPS rig (`assets/Fps Rig/FpsGlock.fbx`), retiring the temporary character-cloned arms and establishing full `Idle`, `Fire`, and `Reload` animation integration.
2. **Phase B**: Implements the foundation of combat progression with server-authoritative headshots, run-based XP and leveling, three physical in-world Talent Altars, and a 12-talent prototype system featuring Neutral, Professor Volta (lightning/stun), and Sergeant Bravo (piercing/damage) talents with Blue (Rare), Purple (Epic), and Red (Mythic) rarities.

---

## Phase A Requirements — New FPS Rig Migration

### 1. Ready-Made Animated FPS Rig
- Inspect and import `assets/Fps Rig/FpsGlock.fbx`:
  - Single skeletal rig containing both arms (`UpperArm`, `LowerArm`, `Hand`, fingers) and weapon bones (`Root`, `Slide`, `Trigger`, `Magazine`, `SlideCatch`).
  - Embedded animation stacks: `Idle`, `Shoot` (Fire), `Reload`, `Inspect`, and `Grip`.
- Must be imported through Roblox Studio's 3D Importer and saved as a live `.rbxm` (`assets/FpsGlock.rbxm`), mapped through Rojo to `ReplicatedStorage.Assets.FpsGlock`.
- Publish the imported animation clips to obtain valid `rbxassetid://` IDs for `Idle`, `Fire`, and `Reload`.

### 2. Viewmodel Architecture & Old Rig Removal
- Replace the character-clone R15 viewmodel in `src/client/ViewmodelController.luau` with a single client-only clone of `ReplicatedStorage.Assets.FpsGlock`.
- Remove old character-part cloning, synthetic `RightGrip` creation, and `assets/Arms.rbxm` dependencies.
- Configure all viewmodel parts with cosmetic properties: `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `CastShadow = false`, `Massless = true`.
- Anchor only the root part; maintain `CurrentCamera` following in `RenderStepped` with `CameraOffset`, movement bob, and recoil kick.
- Real character limbs remain locally hidden (`LocalTransparencyModifier = 1`).

### 3. Animation Playback Integration
- Play `Idle` looped at `Enum.AnimationPriority.Idle`.
- Play `Fire` (`Shoot`) at `Enum.AnimationPriority.Action` on accepted LMB clicks.
- Play `Reload` at `Enum.AnimationPriority.Action` when reload starts, scaled to match gameplay `ReloadDuration` (1.5s).
- Visual animation timing must never dictate server gameplay or ammo authority.

---

## Phase B Requirements — Headshots, Progression & Talents

### 1. Server-Authoritative Headshot System
- In hitscan raycasting, determine headshots strictly on the server: `hitPart.Name == "Head"`.
- Never accept client-provided headshot flags.
- Apply `HeadshotMultiplier = 2.0` (25 base body damage, 50 headshot damage).

### 2. Combat Event / Modifier Architecture
- Centralize hit processing into a server `CombatService`:
  - Input: Attacker, Target, HitPart, BaseDamage, WeaponId, HitPosition.
  - Computes modifiers (headshot multiplier, talent damage bonuses, vulnerability).
  - Applies damage to Humanoid.
  - Dispatches hooks: `onHit`, `onHeadshot`, `onKill`, `onHeadshotKill`.

### 3. XP & Leveling Progression
- Run-based progression (no persistent DataStore).
- `ZombieKillXP = 10`. Prevent duplicate XP awards from the same zombie.
- Level-up requirement formula: `RequiredXP(level) = 30 + ((level - 1) * 10)`.
- Replicate `PlayerLevel`, `PlayerXP`, `PlayerRequiredXP`, and `PendingTalentChoices` via Player Attributes.
- Reaching threshold increments level, grants a pending talent choice, and triggers Altar roll.

### 4. Talent Rarities & Roster (12 Prototype Talents)
- Rarities: Blue (Rare, 75%), Purple (Epic, 25%), Red (Mythic, prerequisite-gated), Gold (Legendary, excluded from normal rolls).
- Upgrades: Obtaining Purple replaces Blue magnitude (does not stack additively).
- **Neutral**:
  1. *Sharpshooter*: +25% (Blue) / +45% (Purple) Headshot Damage.
  2. *Quick Hands*: -20% (Blue) / -35% (Purple) Reload Duration.
  3. *Extended Magazine*: +4 (Blue) / +8 (Purple) Magazine Capacity.
  4. *Vitality*: +20 (Blue) / +40 (Purple) MaxHealth.
- **Professor Volta**:
  5. *Arc Discharge*: On headshot, chain lightning damages 1 (Blue, 20 dmg) / 2 (Purple, 25 dmg) nearby zombies within 18 studs.
  6. *Static Shock*: Headshot has 20% (Blue, 1.0s) / 35% (Purple, 1.5s) chance to stun target.
  7. *Conductive Target* (Purple-only): Shocked enemies take +25% damage from all sources.
  8. *Tesla Cascade* (Red / Mythic): Prerequisite: owns Arc Discharge + 1 Volta boon. Chain lightning bounces to +3 additional zombies (capped, no duplicate hits).
- **Sergeant Bravo**:
  9. *AP Core*: Bullets pierce 1 (Blue) / 2 (Purple) additional zombies.
  10. *Large Caliber*: +20% (Blue) / +35% (Purple) Base Damage.
  11. *Combat Reload*: Headshot kill grants -30% (Blue) / -50% (Purple) duration to the next reload.
  12. *Deadeye* (Red / Mythic): Consecutive headshots grant +10% headshot damage per hit (max +50%). Body hits or misses reset streak.

### 5. Physical Talent Altars
- Three physical pedestal models placed on the Baseplate.
- Each altar displays Talent Name, Category, Rarity Badge, and Description via BillboardGui/SurfaceGui.
- Interacted with via `ProximityPrompt` ("Select Talent", 0.6s hold).
- Server validates that the player has pending choices, grants the chosen talent, consumes one choice, clears the altars, and re-rolls if choices remain.
- Client cannot select arbitrary talent IDs; selection is verified server-side.

### 6. Test & Debug Mode
- Configurable `TalentConfig.DebugMode = true` to force specific rarities (e.g. Altar 1 = Blue, Altar 2 = Purple, Altar 3 = Mythic) and 1-kill level-up for rapid Studio validation.

---

## Non-Negotiable Architecture Constraints

- **Two Separate Commits**: Phase A (FPS Rig Migration) must be implemented and tested first before Phase B (Headshots + Talents).
- **Server Authority**: Damage calculation, headshot validation, talent ownership, XP grants, and prompt validation remain 100% server-authoritative.
- **No Client Manipulation**: The client never determines headshot state, XP, or talent grants.
- **Out of Scope**: Do NOT implement AKM, stamina, map redesign, PathfindingService rewrite, or multiplayer.

---

## Acceptance Criteria

### Phase A:
1. `assets/Fps Rig/FpsGlock.fbx` is imported via Roblox Studio and synced as `assets/FpsGlock.rbxm`.
2. First-person viewmodel cleanly renders the new Glock rig and arms.
3. Old character-cloned viewmodel is fully retired with zero residual artifacts.
4. `Idle` animation loops continuously in first person.
5. Firing plays `Shoot` animation and procedural recoil kick.
6. Reloading plays `Reload` animation synchronized to 1.5s.
7. Shooting and reloading remain fully functional on the server.

### Phase B:
8. Headshots hit `Head` and deal 50 damage (2.0x multiplier), killing 80 HP zombies in 2 shots.
9. Body shots continue dealing 25 damage (4 shots to kill).
10. Killing zombies awards 10 XP; leveling up grants 1 pending choice.
11. Three physical altars appear with Blue/Purple/Red talent options.
12. Selecting an altar grants the talent, updates player stats, and applies effects immediately.
13. Arc Discharge / Tesla Cascade chains lightning without infinite recursion.
14. AP Core pierces additional zombies along the ray trajectory.
15. Deadeye builds consecutive headshot stacks and resets on body shot/miss.
16. Roblox Studio Output log remains completely free of errors.
