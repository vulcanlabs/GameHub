# Don’t Touch the Water

First-person parkour over generated levels. Fall in and the splash wakes whatever is swimming. Gifts from the hub shove you, change level, or add monsters.

The game you run is Godot: [`games/dont-touch-the-water/godot`](../games/dont-touch-the-water/godot). Linking and install steps are in [install.md](install.md). The React Three.js files next to `godot/` are the previous browser build. The hub does not open them while the registry runtime is `desktop`.

## Controls

| Input | Does |
| --- | --- |
| Click | Capture the mouse |
| WASD | Move |
| Shift | Sprint |
| Space | Jump on land. In water, stroke forward |
| Mouse | Look |
| Esc | Pause. Esc again resumes |
| F1–F12 | Same actions as gifts. F5 is unused |

Swim onto a pad to climb out. The game does not move you to a nearby pad.

## Actions

Names match `lib/gifts.ts`. The hub maps a gift name to one of these. F keys run them without a gift.

| Key | Action | Result |
| --- | --- | --- |
| F1 | `spawn_monster` | Another monster of the selected type |
| F2 | `crow_attack` | A crow flies in and knocks you |
| F3 / F4 | `up_1` / `down_1` | One level |
| F6 / F7 | `up_5` / `down_5` | Five levels |
| F8 | `custom` | Step by the custom amount of levels (negative goes back) |
| F9 | `reset` | Restart the current level |
| F10 / F11 | `push_forward` / `push_back` | Shove along your look direction |
| F12 | `push_water` | Shove off the platform you are standing on |

`repeatCount` from a streak-ending gift runs the action that many times, up to 10.

## Rules copied from the browser build

- 8 levels. Each level is a run of jumps, longer than the one before. The last pad of a level starts the next one. There is no mid-level checkpoint. Death sends you back to that level's first pad.
- Some pads slide. Red bars spin in the gaps. Touching a bar knocks you off.
- Difficulty sets gap size and minimum platform width: Easy, Normal, Hard, Nightmare. Changing it rebuilds the current level and sends you to its start.
- Land speed 6.5, sprint 13. Water 3.5, water sprint 8. Gravity 22. Jump velocity 8. Hold Shift to sprint.
- Water is the plane y = 0. Touching it splashes and every monster charges. The shadow type also blinks closer.
- A charging monster catches you only while you are in the water and within 2.6 units. On a platform it gives up after 1.6 seconds.
- Death waits 2.4 seconds with the monster in front of the camera and blood across the screen, then you respawn at the start of the current level.
- Five crows and nine bats orbit until a crow attack is triggered.

Pause settings are monster type, difficulty, field of view (60–120), push strength (6–24), and custom step. Resume writes them with `PUT /api/v1/devices/settings?slug=dont-touch-the-water`, which is the same `GameConfig` the hub settings tab edits.
