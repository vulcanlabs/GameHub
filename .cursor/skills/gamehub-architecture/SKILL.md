---
name: gamehub-architecture
description: >-
  Orient to Game Hub layout, stack, gift pipeline, and constraints. Use when
  starting work in this repo, unsure where code lives, or planning cross-cutting
  changes across hub, games, auth, or TikFinity.
---

# Game Hub architecture

## Read first

1. `docs/architecture.md` (how a gift reaches a game)
2. `docs/install.md` for setup and first use
3. `openapi/openapi.yaml` if touching HTTP

## Mental model

- **Hub** (`app/`, `lib/`): navigation, Google auth, roles, gift bindings, hook URLs, admin users.
- **Games** (`games/<slug>/` + `games/registry.ts`): `runtime: "web"` is Three.js. `runtime: "desktop"` is a Godot app that long-polls the hub. The hub links and configures both. TikFinity stays on the bridge.
- **Bridge** (`bridge/tikfinity-bridge.mjs`): PC-local TikFinity WS → user hook HTTP.
- **Legacy** (`legacy/`): old single-file HTML — do not extend.

## Hot paths

| Need | Go here |
| --- | --- |
| Register / list games | `games/registry.ts` |
| Gift catalog / defaults | `lib/gifts.ts` |
| SSE publish / subscribe | `lib/live.ts` |
| Hook ingest + gift parse | `lib/hooks.ts`, `app/api/v1/hooks/` |
| Desktop link, poll, settings | `lib/devices.ts`, `app/api/v1/devices/` |
| Don’t Touch the Water | `games/dont-touch-the-water/godot` |
| Session gates | `lib/session-guards.ts`, `lib/roles.ts` |
| Auth.js | `lib/auth.ts` |
| Prisma models | `prisma/schema.prisma` |

## Stop conditions

Stop and ask if the task needs Redis multi-instance SSE, payments, Discord unlock, or copying an external Discord game.
