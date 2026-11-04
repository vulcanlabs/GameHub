---
name: add-gamehub-game
description: >-
  Add a game to Game Hub (folder, registry, actions, docs). Use when the user
  asks to add a game, scaffold a new slug, or wire a playable into the hub
  library. Web games are Three.js. Desktop games are Godot and use the device
  long-poll.
---

# Add a Game Hub game

Follow `docs/adding-a-game.md`. Summary:

1. Scaffold `games/<kebab-slug>/` plus a `README.md`.
2. Web: React Three.js entry, hub chrome off `/play/[slug]`, `runtime: "web"`.
3. Desktop: Godot 4 project, `runtime: "desktop"`. Poll `GET /api/v1/devices/live`. Do not open TikFinity. Follow `.cursor/skills/gamehub-godot/SKILL.md`.
4. Append metadata to `games/registry.ts`, including `runtime`.
5. Render web games from `app/play/[slug]/page.tsx`. Desktop games get a link code on the hub page instead.
6. Reuse `lib/gifts.ts` `ACTIONS` when possible. New actions update the catalog, the game, and defaults together.
7. Confirm a normal user without `active` and a future `accessUntil` cannot play.
8. Do not embed the game as an HTML string or load Three from a CDN.

Reference: `games/dont-touch-the-water/godot` (desktop) and the Three.js files beside it (old web client).
