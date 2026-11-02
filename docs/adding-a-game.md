# Adding a game

## Checklist

1. Create `games/<slug>/` with:
   - React play entry (client component that mounts Three.js)
   - `README.md` — controls and LIVE actions
   - Optional modules: map, player, monsters, actions, settings types
2. Add a row to [`games/registry.ts`](../games/registry.ts) (`slug`, `title`, `emoji`, `genre`, `blurb`, `version`).
3. Wire [`app/play/[slug]/page.tsx`](../app/play/[slug]/page.tsx) to render the new entry (same pattern as Don’t Touch the Water).
4. Reuse shared actions if possible (`lib/gifts.ts` `ACTIONS` / `DEFAULT_BINDINGS`). New actions need:
   - Entry in `ACTIONS`
   - Handling in the game
   - Optional default bindings
5. Confirm active-user gating still applies (play page + game APIs use `requireActivePlayer` / `canAccessGames`).
6. Update OpenAPI only if you add new HTTP endpoints.

## Conventions

- **Slug** is kebab-case and matches the folder name.
- Settings shape today: `{ monster, diff, fov, push, custom }` in `GameConfig.settings`. Extend carefully and keep `asSettings` / validation in sync.
- Play opens as a **popup** from the hub (`window.open('/play/<slug>')`). Keep hub chrome off the play page.
- Live gifts: subscribe to `GET /api/v1/games/<slug>/live` (SSE). Events look like `{ type: 'action', giftName, action, repeatCount, label? }`.
- Prefer npm `three` imports. No CDN. No `document.write` of a full HTML game.

## Reference implementation

[`games/dont-touch-the-water/`](../games/dont-touch-the-water/) — scene, bent parkour map, sprint, surface swim, pause settings, SSE consumer.
