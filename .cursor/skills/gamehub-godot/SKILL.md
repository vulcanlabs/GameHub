---
name: gamehub-godot
description: >-
  Edit Game Hub Godot desktop games, the device link, long-poll, and settings
  API. Use when the user mentions Godot, Don't Touch the Water, Pulse Beacon,
  a desktop build, device token, or replacing the Three.js client.
---

# Godot games on Game Hub

TikFinity stays on `bridge/tikfinity-bridge.mjs`. A Godot project never opens `ws://127.0.0.1:21213`.

## Where

| Game | Project | Slug | Registry runtime |
| --- | --- | --- | --- |
| Don’t Touch the Water | `games/dont-touch-the-water/godot` | `dont-touch-the-water` | `desktop` |
| Pulse Beacon | `games/pulse-beacon` | `pulse-beacon` | `desktop` |
| Don’t Touch the Lava | `games/dont-touch-the-lava` | `dont-touch-the-lava` | `desktop` |

Three.js for Don’t Touch the Water is the old browser client beside `godot/`. Do not wire it back into `/play` unless the user asks to flip `runtime` to `web`.

Read [docs/dont-touch-the-water.md](../../docs/dont-touch-the-water.md) before changing movement, monsters, or action names. Action ids live in `lib/gifts.ts` and must match the `match` in `game.gd`.

## Device protocol

Public in `middleware.ts` (no session cookie). Each handler calls `requireDevice`.

| Call | Use |
| --- | --- |
| `POST /api/v1/devices/link` | `{ code, slug, deviceName }` → `{ token }` once |
| `GET /api/v1/devices/live?slug=` | Bearer. Hold ~25s. `{ events: [...] }` |
| `POST /api/v1/devices/state` | Bearer. `{ slug, status: ready\|paused, score? }` |
| `GET` / `PUT /api/v1/devices/settings?slug=` | Bearer. Same `GameSettings` as the hub |

Token file for the water game: `user://dont_touch_the_water.cfg` stores the hub URL only. The device token stays in memory for that launch, so the next start asks for a new code. Store the hash only on the server (`lib/devices.ts`). Linking still fails when the account lease has ended.

`repeatCount` is applied in the game, capped at 10. Do not publish gifts from `devices/state`.

## Check

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path games/dont-touch-the-water/godot --quit-after 120 -- --playtest
```

Expect `playtest ok`. Script errors print above that line.

Hub link codes only succeed when `isDesktopGame(slug)` is true.
