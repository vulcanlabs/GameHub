# Don’t Touch the Lava

First-person parkour over a generated platform chain. Touch the lava and you lose a life. Finish the last platform of each level. Beat the configured number of levels to win.

The game you run is Godot: [`games/dont-touch-the-lava`](../games/dont-touch-the-lava). It starts fullscreen and skips the hub link screen. Set `SKIP_LINK` to false in `scripts/main.gd` when that screen should show again.

## Controls

| Input | Does |
| --- | --- |
| Click | Capture the mouse |
| WASD | Move |
| Space | Jump |
| Mouse | Look |
| Esc | Pause. Change lives, levels, and platforms. Esc again resumes |
| F11 | Leave or return to fullscreen. The pause menu has the same button. |

The run starts at 3 lives, 5 levels, and 8 platforms. Pause-menu edits apply on the next level, or immediately if you restart.

## Generator

`scripts/map_gen.gd` builds one chain. The seed is the level index, so the same settings rebuild the same course. Each next platform stays in the 180° in front of the last jump, so the run keeps facing forward. The goal platform is the farthest from the start. Gaps vary, and every gap stays inside a running jump.

Gifts are not applied yet. The client still long-polls so the account lease stays checked.
