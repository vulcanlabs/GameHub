# Architecture

Game Hub is one Next.js App Router app. The hub owns accounts, gift bindings, and TikFinity hooks. Games are separate source trees under `games/`, loaded by play routes.

```
TikTok LIVE → TikFinity (desktop) → ws://127.0.0.1:21213
  → bridge/tikfinity-bridge.mjs
  → POST /api/v1/hooks/{token}/events
  → user gift bindings
  → SSE /api/v1/games/{slug}/live
  → Three.js game window
```

## Layout

| Path | Role |
| --- | --- |
| `app/` | Hub UI, play route, API route handlers |
| `games/registry.ts` | Catalog the hub reads |
| `games/<slug>/` | One game package (Three.js + React entry) |
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
- In-memory SSE fan-out in `lib/live.ts` (single Node process only).

## Auth and access

- Google only. `AUTH_URL` is the **site origin** (`http://localhost:3000`), never the callback path.
- Google Console redirect URI: `http://localhost:3000/api/auth/callback/google`.
- Roles: `admin` | `user`. Owner email + `ADMIN_EMAILS` are admin.
- New users start `active: false`. Only active users (or admins) see games / hit game APIs.
- Admin UI: `/admin/users` — activate, deactivate, delete (not self / not admins).

## Gift pipeline

1. User maps gift name → action in hub (stored in `GameConfig.bindings`).
2. Bridge forwards TikFinity `gift` events to that user’s hook URL.
3. Hook resolves binding, publishes onto SSE for that `userId` + `slug`.
4. Game window listens and runs `gameAction`.

Streak gifts (`giftType === 1` && `repeatEnd === false`) are ignored. `repeatCount` capped at 10. Fingerprints dedupe for 30s.

## Do not

- Put game source inside a string in the hub.
- Use TikFinity’s per-action webhook UI as the primary integration (it bypasses the in-hub gift map).
- Assume multi-instance SSE works without Redis (out of scope until needed).
- Sell/copy third-party Discord games into this repo.
