# Task: Pistol + Basic Zombie Combat Vertical Slice

## Goal

Create the first complete combat loop for Zombilka.

The player should be able to fight one basic zombie using one pistol.

The zombie must be able to chase and attack the player, receive pistol damage, and die.

This is a vertical slice, not the final production weapon or enemy system.

---

## Pistol requirements

Implement one pistol.

Controls:

- Left Mouse Button: fire
- R: reload

Behavior:

- semi-automatic
- one shot per click
- hitscan / raycast-based shooting
- configurable damage
- configurable range
- configurable fire rate / minimum time between shots
- magazine ammunition
- reserve ammunition
- reload duration
- cannot fire while reloading
- cannot fire with an empty magazine
- reload cannot exceed magazine capacity
- reserve ammo decreases correctly

Use reasonable prototype values.

For example, values may be around:

- magazine: 12
- reserve: 60
- damage: enough that several body shots kill the prototype zombie

Exact balance values are not important yet.

Keep weapon statistics in a sensible configuration location rather than scattering magic numbers across scripts.

---

## Weapon networking and security

This is a Roblox game.

The client must NOT be trusted to decide important combat results.

The client may communicate shooting intent and aim information.

The server must validate important state such as:

- whether the player is allowed to fire
- whether the pistol is currently reloading
- fire-rate limits
- ammunition
- weapon identity where relevant
- damage

The client must never be able to send an arbitrary damage number that the server simply accepts.

Do not create an excessively complicated anti-cheat system during this milestone.

We only need sensible server authority and validation for the prototype.

---

## Shooting

Use Roblox raycasting / hitscan.

The weapon should shoot toward the player's crosshair / camera aim.

The implementation should avoid trusting arbitrary client-selected victims.

Antigravity must determine the simplest secure architecture after inspecting the project.

The prototype does not need realistic ballistics or physical bullets.

---

## Pistol presentation

The combat system must be testable and understandable in first person.

A polished production-quality weapon model is NOT required during this milestone.

If there is no suitable pistol asset already present in the project:

- do not depend on a random Toolbox asset
- do not block development on art
- use the simplest reasonable temporary presentation or clearly separate gameplay from future viewmodel work

Do not build a complex first-person arms/viewmodel animation system yet.

Minimal feedback is acceptable, such as:

- simple shot feedback
- ammo display
- optional minimal hit feedback

Only add what is useful for testing the combat loop.

---

## Ammo UI

The player should have a very simple temporary ammo display.

It may show something like:

12 / 60

This is prototype UI.

Do not create a large HUD framework.

The existing crosshair must continue to work.

---

## Basic zombie requirements

Create one prototype zombie enemy.

The zombie needs:

- health
- detection of a living player
- target selection
- chasing
- close-range attack
- attack cooldown
- damage to player
- death
- stopping all combat behavior after death

For this milestone, prioritize reliable behavior over sophisticated AI.

---

## Zombie movement

Use Roblox-native systems where practical.

The zombie should be able to move toward the player.

If PathfindingService is genuinely necessary for the current simple test environment, it may be used.

However:

- do not build an advanced navigation framework yet
- do not create complicated state machines unless the current problem actually requires them
- do not overengineer obstacle handling for a flat prototype arena

The architecture should allow better navigation later without forcing us to implement all of it now.

---

## Zombie targeting

For the current milestone:

- one zombie is enough
- target a living player
- ignore dead players
- if the target dies or becomes invalid, stop attacking and reacquire appropriately

Design the code so that multiple zombies could be supported later without requiring a complete rewrite, but do NOT build wave spawning yet.

---

## Zombie attack

When sufficiently close to the player:

- stop or slow appropriately
- attack
- apply server-authoritative damage
- respect an attack cooldown
- do not apply damage every frame

The prototype does not require elaborate attack animations yet.

---

## Player health and death

Use Roblox's existing Humanoid health/death behavior where practical.

The zombie must be capable of killing the player.

After the player's normal Roblox respawn:

- first-person camera must still work
- crosshair must still work
- pistol controls must work again
- ammo state must initialize correctly
- zombies must not keep invalid references to the previous dead Character

Do not build a custom respawn system unless necessary.

---

## Zombie health and death

The pistol must be able to damage the zombie.

At 0 HP:

- the zombie dies
- it no longer moves
- it no longer attacks
- it cannot continue dealing damage

A sophisticated corpse/despawn system is not required yet.

---

## Test zombie

The milestone must provide a practical way to test the zombie in Roblox Studio.

Determine the cleanest solution after inspecting the repository.

Possible approaches include:

- a simple prototype zombie model that exists through Rojo-managed project files
- a server-created test zombie
- another simple reproducible development setup

Do NOT rely on the developer manually rebuilding the zombie every time Studio starts.

Avoid random external Toolbox dependencies unless explicitly approved.

---

## Architecture goals

Keep the system modular enough that we can later add:

- Shotgun
- AKM
- additional weapons
- additional zombie types
- waves
- upgrades / Patrons

But do NOT implement those systems now.

Avoid premature abstractions.

We specifically do NOT want:

- a huge generic weapon framework
- a huge enemy framework
- a giant dependency injection system
- unnecessary service layers
- speculative systems for features we have not built

Prefer the minimum architecture that cleanly supports this vertical slice and can reasonably evolve.

---

## Do not implement

Do NOT implement during this milestone:

- Shotgun
- AKM
- weapon switching
- weapon inventory
- melee
- weapon pickups
- Patron upgrades
- boon selection
- waves
- encounter manager
- multiple zombie classes
- elite zombies
- bosses
- loot
- economy
- complex recoil system
- polished weapon animations
- first-person arm rig
- advanced zombie animations
- blood/gore system
- sound system overhaul
- map generation
- large map
- sprint
- slide
- dash
- custom character movement
- save data

Do not modify unrelated working FPS systems unless necessary.

---

## Acceptance criteria

The milestone is successful when all of the following can be demonstrated in Roblox Studio:

1. Player spawns in first person.
2. Existing crosshair works.
3. Player has access to the prototype pistol.
4. Left click fires one pistol shot.
5. Holding the mouse does not turn the pistol into automatic fire.
6. Magazine ammo decreases correctly.
7. Empty magazine cannot fire.
8. R reloads the pistol.
9. Reload uses reserve ammo correctly.
10. Pistol raycast can hit the zombie.
11. Zombie loses health from valid pistol hits.
12. Client cannot simply choose an arbitrary damage value.
13. Zombie detects the player.
14. Zombie chases the player.
15. Zombie attacks only at close range.
16. Zombie attack respects a cooldown.
17. Zombie damages the player.
18. Zombie can kill the player.
19. Zombie dies when its health reaches zero.
20. Dead zombie stops moving and attacking.
21. After player respawn, FPS camera and crosshair still work.
22. After player respawn, pistol controls work again.
23. Zombie does not keep attacking the destroyed old Character.
24. Roblox Studio Output contains no repeating runtime errors.
25. Existing FPS foundation is not broken.

---

## Verification

The implementation must eventually be tested manually in Roblox Studio.

The manual test should include:

- spawn
- fire pistol
- verify semi-auto behavior
- empty magazine
- attempt empty shot
- reload
- verify ammo counts
- shoot zombie
- verify zombie HP changes
- allow zombie to chase player
- allow zombie to attack
- allow zombie to kill player
- respawn
- verify FPS systems still work
- verify pistol works after respawn
- kill zombie
- verify zombie stops completely
- inspect Output for errors
