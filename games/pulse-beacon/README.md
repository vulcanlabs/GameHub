# Pulse Beacon

Godot 4 desktop client for Game Hub. Gifts move a beacon. The app talks only to the hub. It does not open TikFinity.

## Run

1. Install Godot 4.3 or newer.
2. Import this folder (`games/pulse-beacon`).
3. Press Play in the editor, or export a desktop build for the stream PC.
4. In the hub, open Pulse Beacon and choose **Create link code**.
5. Enter the hub origin (`http://localhost:3000`), the code, and a name for this PC.

The link token is stored in Godot’s `user://pulse_beacon.cfg`. **Unlink this PC** deletes that local file. Revoke on the hub page kills the token even if the file is copied.

## Actions

The hub still maps gift name to action (`lib/gifts.ts`). This scene applies the action name:

| Action | Motion |
| --- | --- |
| `push_forward` | Right |
| `push_back`, `crow_attack` | Left |
| `push_water`, `down_1` | Down |
| `up_1`, `custom` | Up |
| `up_5` / `down_5` | Five steps up or down |
| `spawn_monster` | Orange flash, no move |
| `reset` | Back to center |

`repeatCount` repeats a one-step move. Use the hub **Test** button with this window polling.

Access ends when the account lease expires, the account is deactivated, or the device is revoked. The app then shows the hub error and returns to the link screen.
