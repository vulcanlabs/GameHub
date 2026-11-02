---
name: add-gamehub-game
description: >-
  Add a new Three.js game package to Game Hub (folder, registry, play route,
  actions, docs). Use when the user asks to add a game, scaffold a new slug, or
  wire a playable into the hub library.
---

# Add a Game Hub game

Follow `docs/adding-a-game.md`. Summary:

1. Scaffold `games/<kebab-slug>/` with a client React Three.js entry + `README.md`.
2. Export the play component; keep hub chrome off the play page.
3. Append metadata to `games/registry.ts`.
4. Render it from `app/play/[slug]/page.tsx` (branch or dynamic import by slug).
5. Reuse `lib/gifts.ts` `ACTIONS` when possible; if new actions are required, update catalog, game handler, and defaults together.
6. Confirm inactive users cannot play (`canAccessGames` / `requireActivePlayer`).
7. Do not embed the game as an HTML string or load Three from a CDN.

Reference: `games/dont-touch-the-water/`.
