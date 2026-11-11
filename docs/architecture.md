# Architecture

Game Hub is one Next.js App Router app. The hub owns accounts, gift bindings, and TikFinity hooks. Games are separate source trees under `games/`, loaded by play routes.

```
TikTok LIVE → TikFinity (desktop) → ws://127.0.0.1:21213
  → bridge/tikfinity-bridge.mjs
  → POST /api/v1/hooks/{token}/events
  → user gift bindings
  → lib/live.ts
       → SSE /api/v1/games/{slug}/live → browser game
       → GET /api/v1/devices/live      → Godot desktop app
```

The desktop app never opens `ws://127.0.0.1:21213`. A device token from a one-time hub code is the only credential it holds. Each poll checks the account lease. These routes skip the session cookie in `middleware.ts` and authenticate themselves: `POST /api/v1/devices/link`, `GET /api/v1/devices/live`, `POST /api/v1/devices/state`, `GET` and `PUT /api/v1/devices/settings`.

First-time setup is [install.md](install.md).

## How it works

Four pieces, and only the hub is allowed to connect them.

**Account.** Google sign-in creates a user with a secret hook token. Admins open games immediately. Everyone else needs `active` and a future `accessUntil`, set on `/admin/users`. That lease is checked on the hook, on the browser, and on every desktop poll.

**Gift map.** Each user has one `GameConfig` per game slug: which gift name runs which action, plus settings. Water and Pulse Beacon store monster, difficulty, field of view, push, and custom checkpoint step. Don’t Touch the Lava stores lives, levels to beat, and platforms per level. Don’t Touch the Grass stores `{ version: 1 }` until it has settings. The hub page edits that row. The Godot pause menu writes the same row through the device token.

**TikFinity.** The desktop app on the stream PC exposes gifts only at `ws://127.0.0.1:21213/`. `bridge/tikfinity-bridge.mjs` forwards `gift` events to `POST /api/v1/hooks/{token}/events`. The hook drops streak partials, unknown names, and duplicates, then `lib/live.ts` publishes `{ type: "action", giftName, action, repeatCount }` for that user and slug. The hub **Test** button publishes the same event without TikFinity.

**Game.** Don’t Touch the Water is a Godot 4 project at `games/dont-touch-the-water/godot`. After linking, it loads settings, then long-polls `GET /api/v1/devices/live?slug=dont-touch-the-water` for about 25 seconds at a time. Empty `events` means the lease is still valid. An action name (`push_forward`, `spawn_monster`, `up_1`, …) is applied locally. `repeatCount` repeats it, capped at 10. `POST /api/v1/devices/state` reports `ready` or `paused`. It cannot create a gift.

The previous Three.js canvas is still in `games/dont-touch-the-water/` outside `godot/`. The registry row is `runtime: "desktop"`, so the hub shows a link code instead of the browser play window. Pulse Beacon (`games/pulse-beacon`) is a smaller Godot client on the same protocol. Don’t Touch the Lava (`games/dont-touch-the-lava`) is a first-person platform chain on that protocol. Its levels are generated in the game. Gift actions are not wired yet. See [dont-touch-the-lava.md](dont-touch-the-lava.md). Don’t Touch the Grass (`games/dont-touch-the-grass`) is a first-person Backrooms parkour game on the same runtime: 50 levels, safe platforms, lethal grass, giant ants, and a spider from level 25. Keyboard actions F1–F9 work without TikTok. It does not poll the device API yet. See [dont-touch-the-grass.md](dont-touch-the-grass.md).

`lib/live.ts` keeps subscribers in memory. One Node process is the whole fan-out. Do not run a second hub and expect gifts to cross it.

## Layout

| Path | Role |
| --- | --- |
| `app/` | Hub UI, play route, API route handlers |
| `games/registry.ts` | Catalog the hub reads |
| `games/<slug>/` | One game. Web: Three.js + React. Desktop: Godot 4 project (`godot/` inside the slug, or the folder itself) |
| `lib/` | Auth, Prisma, gifts, live SSE, roles, guards |
| `bridge/` | Local TikFinity → HTTP forwarder |
| `prisma/` | SQLite schema |
| `openapi/openapi.yaml` | HTTP contract (update when APIs change) |
| `legacy/` | Original single-file export — reference only |
| `docs/` | Human + agent documentation |

## Stack rules

- Next.js App Router. Before using unfamiliar Next APIs, read `node_modules/next/dist/docs/` (see root `AGENTS.md`).
- Auth.js (next-auth v5) + Google + Prisma adapter, **database** sessions.
- Prisma + SQLite locally (`DATABASE_URL=file:./dev.db`).
- Three.js from npm inside game folders — not CDN script tags, not embedded HTML strings.
- In-memory fan-out in `lib/live.ts` (single Node process only). Browser uses SSE. Desktop uses a 25s long-poll on the same bus.

## Auth and access

- Google only. `AUTH_URL` is the **site origin** (`http://localhost:3000`), never the callback path.
- Google Console redirect URI: `http://localhost:3000/api/auth/callback/google`.
- Roles: `admin` | `user`. Owner email + `ADMIN_EMAILS` are admin.
- New users start `active: false` with no `accessUntil`. A normal user needs `active` and `accessUntil` in the future. Admins skip both.
- Admin UI: `/admin/users` — activate, deactivate, set an end date (+1 day, +7 days, +30 days, or a date), cancel that date, delete (not self / not admins).

## Gift pipeline

1. User maps gift name → action in hub (stored in `GameConfig.bindings`).
2. Bridge forwards TikFinity `gift` events to that user’s hook URL.
3. Hook resolves binding, publishes onto SSE for that `userId` + `slug`.
4. A browser game listens on SSE, or a linked desktop app long-polls, and runs the action. `POST /api/v1/devices/state` is a heartbeat and status only. It is not a gift. Desktop settings use `GET` and `PUT /api/v1/devices/settings`.

Streak gifts (`giftType === 1` && `repeatEnd === false`) are ignored. `repeatCount` capped at 10. Fingerprints dedupe for 30s.

## Do not

- Put game source inside a string in the hub.
- Use TikFinity’s per-action webhook UI as the primary integration (it bypasses the in-hub gift map).
- Assume multi-instance SSE works without Redis (out of scope until needed).
- Sell/copy third-party Discord games into this repo.
