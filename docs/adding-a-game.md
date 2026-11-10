# Adding a game

## Checklist

1. Create `games/<slug>/` with a `README.md` for controls and LIVE actions.
   - `runtime: "web"` — React client that mounts Three.js.
   - `runtime: "desktop"` — Godot 4 project (the folder itself, or `godot/` inside it).
2. Add a row to [`games/registry.ts`](../games/registry.ts) (`slug`, `title`, `emoji`, `genre`, `blurb`, `version`, `runtime`).
   - `web` — opened from **Play**.
   - `desktop` — hub shows a link code. See [`games/dont-touch-the-water/godot`](../games/dont-touch-the-water/godot).
3. Wire [`app/play/[slug]/page.tsx`](../app/play/[slug]/page.tsx) only for web games. Desktop slugs redirect to the hub page.
4. Reuse shared actions if possible (`lib/gifts.ts` `ACTIONS` / `DEFAULT_BINDINGS`). New actions need:
   - Entry in `ACTIONS`
   - Handling in the game
   - Optional default bindings
5. Confirm active-user gating still applies (play page + game APIs use `requireActivePlayer` / `canAccessGames`).
6. Update OpenAPI only if you add new HTTP endpoints.

## Conventions

- **Slug** is kebab-case and matches the folder name.
- Settings shape depends on the slug. Water and Pulse Beacon use `{ monster, diff, fov, push, custom }`. Don’t Touch the Lava uses `{ lives, levels, platforms }`. `asSettings(slug, value)` and `validateSettingsInput(slug, body)` keep them apart.
- Web play opens as a **popup** from the hub (`window.open('/play/<slug>')`). Keep hub chrome off the play page. Desktop games do not use that popup.
- Web live gifts: `GET /api/v1/games/<slug>/live` (SSE). Desktop live gifts: `GET /api/v1/devices/live?slug=` with a device bearer. Events look like `{ type: 'action', giftName, action, repeatCount, label? }`.
- Web games import `three` from npm. No CDN. No `document.write` of a full HTML game.

## Reference implementation

[`games/dont-touch-the-water/godot`](../games/dont-touch-the-water/godot) — desktop course, swim, monsters, pause settings, device long-poll. The Three.js files in the parent folder are the previous browser build.
