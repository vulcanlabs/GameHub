# Don’t Touch the Water

First-person parkour over a generated course. Fall in and the splash wakes whatever is swimming. Gifts from the hub shove you, move checkpoints, or add monsters.

The game you run is Godot: [`games/dont-touch-the-water/godot`](../games/dont-touch-the-water/godot). Linking and install steps are in [install.md](install.md). The React Three.js files next to `godot/` are the previous browser build. The hub does not open them while the registry runtime is `desktop`.

## Controls

| Input | Does |
| --- | --- |
| Click | Capture the mouse |
| WASD | Move |
| Shift | Sprint |
| Space | Jump on land. In water, climb the nearest platform |
| Mouse | Look |
| Esc | Pause. Esc again resumes |
| F1–F12 | Same actions as gifts. F5 is unused |

Walking into the side of a platform also climbs out.

## Actions

Names match `lib/gifts.ts`. The hub maps a gift name to one of these. F keys run them without a gift.

| Key | Action | Result |
| --- | --- | --- |
| F1 | `spawn_monster` | Another monster of the selected type |
| F2 | `crow_attack` | A crow flies in and knocks you |
| F3 / F4 | `up_1` / `down_1` | One checkpoint |
| F6 / F7 | `up_5` / `down_5` | Five checkpoints |
| F8 | `custom` | Step by the custom amount (negative goes back) |
| F9 | `reset` | Back to the start |
| F10 / F11 | `push_forward` / `push_back` | Shove along your look direction |
| F12 | `push_water` | Shove off the platform you are standing on |

`repeatCount` from a streak-ending gift runs the action that many times, up to 10.

## Rules copied from the browser build

- 91 platforms. Every 5th is a checkpoint with a pole. The path bends but stays inside x = ±40.
- Difficulty sets gap size and minimum platform width: Easy, Normal, Hard, Nightmare. Changing it rebuilds the course and sends you to the start.
- Land speed 6.5, sprint 10. Water 3.5, water sprint 5.5. Gravity 22. Jump velocity 8.
- Water is the plane y = 0. Touching it splashes and every monster charges. The shadow type also blinks closer.
- A charging monster catches you only while you are in the water and within 2.6 units. On a platform it gives up after 1.6 seconds.
- Death waits 1.4 seconds, then you respawn on your current checkpoint.
- Five crows and nine bats orbit until a crow attack is triggered.

Pause settings are monster type, difficulty, field of view (60–120), push strength (6–24), and custom step. Resume writes them with `PUT /api/v1/devices/settings?slug=dont-touch-the-water`, which is the same `GameConfig` the hub settings tab edits.
