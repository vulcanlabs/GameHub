---
name: gamehub-architecture
description: >-
  Orient to Game Hub layout, stack, gift pipeline, and constraints. Use when
  starting work in this repo, unsure where code lives, or planning cross-cutting
  changes across hub, games, auth, or TikFinity.
---

# Game Hub architecture

## Read first

1. `docs/architecture.md`
2. `README.md` (run / env)
3. `openapi/openapi.yaml` if touching HTTP

## Mental model

- **Hub** (`app/`, `lib/`): navigation, Google auth, roles, gift bindings, hook URLs, admin users.
- **Games** (`games/<slug>/` + `games/registry.ts`): Three.js playables; hub only links and configures them.
- **Bridge** (`bridge/tikfinity-bridge.mjs`): PC-local TikFinity WS → user hook HTTP.
- **Legacy** (`legacy/`): old single-file HTML — do not extend.

## Hot paths

| Need | Go here |
| --- | --- |
| Register / list games | `games/registry.ts` |
| Gift catalog / defaults | `lib/gifts.ts` |
| SSE publish / subscribe | `lib/live.ts` |
| Hook ingest + gift parse | `lib/hooks.ts`, `app/api/v1/hooks/` |
| Session gates | `lib/session-guards.ts`, `lib/roles.ts` |
| Auth.js | `lib/auth.ts` |
| Prisma models | `prisma/schema.prisma` |

## Stop conditions

Stop and ask if the task needs Redis multi-instance SSE, payments, Discord unlock, or copying an external Discord game.
