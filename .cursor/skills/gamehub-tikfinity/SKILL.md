---
name: gamehub-tikfinity
description: >-
  Work on TikFinity gift ingest, per-user hook URLs, bridge script, SSE live
  stream, or gift→action bindings. Use when debugging gifts, hooks, bridge, or
  LIVE test buttons.
---

# TikFinity / gifts

Read `docs/tikfinity.md`.

## Flow

TikFinity WS `127.0.0.1:21213` → `bridge/tikfinity-bridge.mjs` → `POST /api/v1/hooks/{token}/events` → bindings → `lib/live` SSE → game `EventSource`.

## Rules

- One secret hook URL per user (`User.hookToken`); rotate via `POST /api/v1/hooks/me`.
- Prefer hub gift map + bridge over TikFinity’s per-action webhooks.
- Streak skip, repeatCap 10, 30s fingerprint — keep in `lib/hooks.ts`.
- Inactive non-admin hooks return `403`.
- No TikFinity? Use hub Test → `POST /api/v1/games/{slug}/test`.
- Update `openapi/openapi.yaml` when request/response shapes change.

## Verify

```bash
# bad token → 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  http://localhost:3000/api/v1/hooks/bad/events \
  -H 'Content-Type: application/json' -d '{"giftName":"Rose"}'
```
