# Zombilka Roblox

Zombilka is a zombie shooter being developed in Roblox.

## Current state

- New Roblox project
- Rojo is installed and connected to Roblox Studio
- Source code is edited externally
- Codex is the primary implementation agent
- Antigravity is used for planning/architecture and independent code review

## Architecture

### src/client

Client-side systems:

- input
- camera
- UI
- visual effects
- local weapon presentation

### src/server

Server-side systems:

- damage validation
- zombies
- spawning
- authoritative weapon logic
- game state

### src/shared

Shared:

- configuration
- constants
- reusable modules

## Development workflow

Large feature:

`AI/TASK.md` -> Antigravity creates `AI/PLAN.md` -> Codex implements -> Antigravity creates `AI/REVIEW.md` -> Codex fixes BLOCKER/IMPORTANT issues -> Roblox Studio testing

Small feature:

`AI/TASK.md` -> Codex implementation -> Roblox Studio testing
