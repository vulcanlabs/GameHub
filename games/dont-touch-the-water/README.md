# Don’t Touch the Water

First-person parkour over water for TikTok LIVE. Stay on platforms. Splash alerts the monster.

## Controls

- **WASD** — move
- **Shift** — sprint
- **Space** — jump on land; climb from water
- **Mouse** — look (click canvas to lock)
- **Esc** — pause / release mouse
- **F1–F12** — gift actions (F5 unbound — browser reload)

## Actions

| Key | Action |
| --- | --- |
| F1 | Spawn monster |
| F2 | Crow attack |
| F3 / F4 | ±1 checkpoint |
| F6 / F7 | ±5 checkpoints |
| F8 | Custom checkpoint step |
| F9 | Reset to start |
| F10 / F11 | Push forward / back |
| F12 | Push into water |

## Live gifts

The play page opens an SSE stream at `/api/v1/games/dont-touch-the-water/live`. Hub test buttons and the per-user TikFinity hook publish onto that stream.

## Settings

Monster type, difficulty (Easy / Normal / Hard / Nightmare), FOV, push strength, and custom checkpoint step. Saved per user via the settings API. Also editable from the pause panel.
