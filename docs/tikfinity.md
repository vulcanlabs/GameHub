# TikFinity integration

## Why a bridge exists

TikFinity’s full gift firehose is **local only**: `ws://127.0.0.1:21213/`. The desktop app must run on the streamer’s PC. Built-in “trigger webhook” actions are one URL per gift/action and would ignore the hub gift map.

Game Hub gives each user one secret URL:

```text
{AUTH_URL}/api/v1/hooks/{token}/events
```

Shown on the game dashboard; rotatable via `POST /api/v1/hooks/me`.

## Bridge

```bash
node bridge/tikfinity-bridge.mjs --url 'http://localhost:3000/api/v1/hooks/TOKEN/events'
```

Options: `--ws` (default `ws://127.0.0.1:21213/`), `--slug` (default `dont-touch-the-water`).

The bridge reconnects on close and forwards `event === "gift"` only.

## Server behavior

| Case | Result |
| --- | --- |
| Unknown token | `401` |
| Inactive non-admin user | `403` |
| Streak partial | `202` `{ ignored: true, reason: "streak" }` |
| Unmapped gift name | `202` `{ ignored: true, reason: "unmapped" }` |
| Duplicate fingerprint (30s) | `202` `{ ignored: true, reason: "duplicate" }` |
| Mapped gift | `202` `{ giftName, action, repeatCount }` + SSE publish |

Accepts flat body or TikFinity envelope `{ event, data: { giftName, ... } }`.

## Local test without TikFinity

Use the hub **Test** button (`POST /api/v1/games/{slug}/test`) with the game window open and subscribed to SSE.

## Contract

See [`openapi/openapi.yaml`](../openapi/openapi.yaml). Keep it updated when hook payloads or status codes change.
