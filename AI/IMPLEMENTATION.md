# Implementation

## Summary

Phase B adds server-authoritative headshots, run XP and levels, three physical talent altars, twelve prototype talents, and server-confirmed hit feedback. The runtime-tested FpsGlock rig, camera, crosshair, sprint, and Horde architecture remain in place. No persistent progression or final talent UI was added.

## Files created

- `src/shared/ProgressionConfig.luau`
- `src/shared/TalentConfig.luau`
- `src/shared/TalentDefinitions.luau`
- `src/server/ProgressionService.luau`
- `src/server/TalentService.luau`
- `src/server/CombatService.luau`
- `src/server/TalentAltars.luau`
- `src/client/HitFeedback.luau`

## Files modified

- `src/shared/PistolConfig.luau` — headshot multiplier.
- `src/shared/Remotes.luau` — server-created `CombatFeedback` RemoteEvent.
- `src/server/PistolServer.luau` — routes confirmed server ray hits through CombatService, repeats rays for AP Core, and uses authoritative magazine/reload modifiers.
- `src/server/Zombie.luau` — clears shock on death, suppresses attacks while shocked, and invokes the player-damage hook; existing attack damage, animation, collision, and cleanup remain unchanged.
- `src/server/init.server.luau` — initializes progression, combat feedback, and altars before starting combat and Horde spawning.
- `src/client/PistolController.luau` — manual reload checks replicated maximum magazine capacity.
- `src/client/ViewmodelController.luau` — cosmetic Reload speed reads the server-published actual duration while preserving FpsGlock assets and animation IDs.
- `src/client/init.client.luau` — mounts small server-confirmed hit feedback.
- `AI/IMPLEMENTATION.md` — this report.

## Headshots and central damage path

`PistolServer` still validates the living character, aim direction, fire rate, ammo, and reload state, then performs the raycast on the server. It passes the actual `RaycastResult.Instance` and hit position to `CombatService`. A bullet is a headshot only when that server-hit part is named `Head`; the client sends only aim direction.

The combat context carries Player, WeaponId, Target, HitPart, IsHeadshot, BaseDamage, FinalDamage, Killed, HitPosition, DamageSource, and flags controlling per-shot talent triggers. Damage order is deterministic:

1. Pistol base damage (25).
2. Large Caliber/base damage multiplier.
3. For headshots only: 2.0 headshot multiplier, Sharpshooter multiplier, then Deadeye multiplier.
4. If the shooter owns Conductive Target and the target is currently shocked: 1.25 incoming damage multiplier.

Without talents, a body hit deals 25 and a headshot deals 50. Lightning starts at its talent's 20/25 damage and only receives the Conductive Target modifier; it never triggers another Arc chain or changes Deadeye streak. `CombatService` exposes on-hit, on-headshot, on-kill, on-headshot-kill, reload, and damage-taken hook points through the small TalentService API.

## XP, kill credit, and player run state

`ProgressionService` creates one server-owned state per player on join and removes it on leave. It persists across character respawns within the server run and uses no DataStore. The state stores level, XP, pending choices, owned talent tiers, damage/headshot/reload multipliers, magazine and health bonuses, piercing count, Deadeye streak, next-reload readiness/multiplier, Volta boon count, and base max health.

Every player-caused kill, including chain lightning, calls `awardKillXP(player, zombie)`. The zombie's server-set `XPAwarded` attribute prevents duplicate credit. Each kill grants 10 XP. Required XP for the current level is `30 + ((level - 1) * 10)`; a loop subtracts thresholds and preserves overflow when one award crosses multiple levels. PlayerLevel, PlayerXP, PlayerRequiredXP, and PendingTalentChoices are replicated as Player Attributes.

## Reload, magazine, and health rules

- `PistolMaxMagazine` and `PistolReloadDuration` are server-published Player Attributes for client presentation. The server uses its private run state, not client attribute values, for authority.
- Quick Hands sets the base reload duration multiplier to 0.8 (Blue) or 0.65 (Purple). A ready Combat Reload multiplies that duration by 0.7 (Blue) or 0.5 (Purple) for exactly the next accepted reload, then clears. The result is clamped to at least 0.35 seconds. The server captures that duration for its reload timer and sets `PistolReloadDuration` before setting `PistolReloading = true`; FpsGlock Reload playback reads it. Changes granted during an active reload apply to later reloads.
- Extended Magazine raises maximum capacity by 4 or 8. Granting or upgrading it changes capacity immediately but **does not add loaded rounds**; a later accepted reload fills to the new capacity. A fresh character spawns with a full upgraded magazine, matching the existing spawn rule. Reserve ammunition remains infinite.
- Vitality adds 20 or 40 maximum health. On a grant or upgrade, current health increases only by the newly gained maximum-health amount. Reapplying the same tier is rejected, so it cannot repeatedly heal. On respawn the upgraded maximum and full health are restored.

## Talent roster, rarities, and altars

`TalentDefinitions` centralizes names, descriptions, categories/patrons, tier values, upgrade policy, and prerequisites. Blue is Rare, Purple Epic, Red Mythic, and Gold Legendary in the schema. Normal rolls use 75:25 Blue/Purple weights and a 15% Red replacement chance when an eligible Mythic exists; Gold is never rolled. Three choices have distinct talent IDs. Blue-to-Purple upgrades replace the old tier's magnitude instead of stacking; max-tier and one-time talents do not reroll.

The twelve talents are:

1. Sharpshooter — +25%/+45% headshot-only damage.
2. Quick Hands — 20%/35% reload-duration reduction.
3. Extended Magazine — +4/+8 capacity.
4. Vitality — +20/+40 maximum health.
5. Arc Discharge — one 20-damage / two 25-damage chain targets within 18 studs per jump.
6. Static Shock — 20% chance for 1.0 seconds / 35% chance for 1.5 seconds on a living headshot target.
7. Conductive Target — Purple-only, +25% damage to shocked targets.
8. Tesla Cascade — one-time Red, adds three Arc jumps after Arc Discharge plus another Volta boon is owned.
9. AP Core — one/two additional zombie pierces.
10. Large Caliber — +20%/+35% base bullet damage.
11. Combat Reload — a headshot kill arms one 30%/50% faster reload.
12. Deadeye — one-time Red, +10% headshot damage per consecutive headshot up to +50%.

Three anchored pedestals are created at `(-8, 2, 20)`, `(0, 2, 22)`, and `(8, 2, 20)` on the current Baseplate. Each has a BillboardGui with name, rarity, patron/category, and description plus a `ProximityPrompt` with a 0.6-second hold. When a pending choice exists, the server rolls three options and displays them. A trigger is accepted only from the active player, while alive and near the pedestal, with a pending choice and an exact match to that player's stored server-generated option. Grant consumes one choice, clears the set, and immediately rerolls if more choices remain. Shared physical altars serve one active player at a time; the core state and talent services remain per-player.

## Chain, stun, pierce, and Deadeye safety

- Arc/Tesla choose the nearest valid living zombie within 18 studs of each previous jump. A visited-model set excludes the original target and every prior jump, and a hard cap of five secondary targets prevents loops. Each secondary hit carries attacker ownership for XP but has no on-hit talent recursion.
- Shock saves the original WalkSpeed, sets it to zero, and uses a replacement token with an extended expiry for repeated stuns. The existing zombie attack check also skips attacks during shock. Speed is restored only if the zombie still lives and that stun is still current; zombie death clears shock state.
- AP Core repeats server raycasts in the same direction, excludes already-hit zombie models, advances the origin slightly, subtracts traveled distance, and stops on world geometry or the pierce cap. The client never sends pierce targets.
- Deadeye increments before calculating the first confirmed headshot of a trigger pull, so that first hit gets +10%. A first body hit or a miss resets the streak; reload does not. Secondary pierce and lightning hits do not increment or reset it. Additional pierce headshots use the current streak without increasing it again, while their own headshot effects can still trigger.

## Debug and feedback

`TalentConfig.DebugMode = false` and `FastLeveling = false` by default. Enabling both in Studio makes one zombie kill cross each XP threshold; DebugRollSlots requests Blue, Purple, and Red in order when valid. DebugMode does not bypass server grant prerequisites. Before Tesla's prerequisites are met, the Red slot can offer Deadeye. There are no production admin commands.

The server-created `CombatFeedback` event tells the firing client only whether a confirmed first zombie hit was a body hit or headshot. The client displays brief `HIT` or stronger `HEADSHOT` text below the crosshair. This event carries no gameplay input back to the server.

## Verification performed

- Read the task, plan, project instructions, prior implementation, and review; inspected current pistol, zombie, viewmodel, input, remote, spawner, and UI source before editing.
- Inspected the complete Git diff, including newly created files, and checked Rojo require paths, server-only damage/rarity/XP decisions, single-use reload bonus, duplicate XP guard, finite pierce/chain loops, repeated shock restoration, stunned-zombie attack suppression, and respawn state.
- Parsed `default.project.json` and confirmed `src/server`, `src/client`, and `src/shared` map to the expected Rojo locations. Searched source references for remotes, damage, XP, viewmodel assets, and obsolete reserve ammo.
- Ran `git diff --check`. Rojo, Luau, Selene, and StyLua command-line tools were unavailable in this shell. Roblox Studio Phase B runtime testing has not been performed.

## Deviations from PLAN.md

- Split talent ownership/effects into `TalentService` so `CombatService` stays a small central damage path and `PistolServer` only handles weapon validation and raycasts.
- Phase B uses a server-created, narrowly scoped `CombatFeedback` remote and small client label because no existing hitmarker module was present.
- Debug Red offers only prerequisite-valid Mythics (Deadeye is available immediately); grant validation never bypasses prerequisites.
- XP is awarded from the central damage path after any player-owned lethal hit rather than from `Zombie.onDeath`, so bullet and lightning kills share one credit rule and `ZombieSpawner` remains unchanged.

## Known limitations

- The prototype has a finite set of one-time/max-tier talents. After fewer than three distinct eligible talents remain, the altars stop offering a set of three and warn once; pending choices remain. A later progression design must decide how to spend excess choices.
- If Roblox reports Reload track Length late, visual speed adjusts then and may finish slightly after the server timer. Server ammo timing is unaffected.
- Headshot marker, combat balance, altar readability, shock behavior, and animation timing require Roblox Studio testing. No final talent UI or persistent progression exists.

## Ordered Roblox Studio test checklist

1. Start a new Play session. Confirm FpsGlock, camera, crosshair, ammo, sprint, zombies, Horde, three altars, and a clean Output window. Check initial PlayerLevel=1, PlayerXP=0, PlayerRequiredXP=30, PendingTalentChoices=0.
2. Shoot a zombie body and head: verify 25 and 50 damage, respectively, and different confirmed hit text. Verify the client still sends only aim direction.
3. Kill three zombies: verify +10 XP each, one level-up at 30 XP, PendingTalentChoices=1, and three distinct displayed altar choices. Test XP overflow and successive level thresholds.
4. Approach each pedestal and hold E. Verify only one talent is granted, PendingTalentChoices decrements by one, all choices clear, and another set appears when choices remain. Try triggering with no pending choice and while dead.
5. Enable DebugMode and FastLeveling in `TalentConfig.luau` for a new Studio run. Verify one-kill leveling and Blue/Purple/Red slots; then switch both settings back off.
6. Obtain and upgrade Neutral talents. Verify headshot-only Sharpshooter damage, Quick Hands server timer and FpsGlock Reload speed, Extended Magazine capacity without free loaded rounds, and Vitality health increase only by the gained bonus.
7. Test Volta: headshot chain target count/range and one XP award per chain kill; repeated Static Shock restoration and death during stun; Conductive Target damage; Tesla prerequisite and maximum extra jumps.
8. Test Bravo: AP Core through two aligned zombies and blocked by a wall; Large Caliber before headshot multiplication; one-use Combat Reload with Quick Hands and minimum duration; Deadeye build/reset on head, body, and miss without extra stacks from piercing or lightning.
9. Die and respawn several times. Confirm run state and talents persist within the server session, character health/ammo reset correctly, FpsGlock remains single, and no delayed reload or stun callback corrupts new state.
