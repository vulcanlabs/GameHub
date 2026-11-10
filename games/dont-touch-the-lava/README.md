# Don’t Touch the Lava

First-person platform parkour. Jump the chain. Lava costs a life.

Godot 4 project. It opens straight into the game, fullscreen. The hub link screen is skipped. Gift actions are not used yet.

## Controls

- Click to capture the mouse
- WASD to move
- Space to jump
- Mouse to look
- Esc to pause
- F11, or Fullscreen in the pause menu, to leave or return to fullscreen

## Settings

Edited in the pause menu for this run. A change applies on the next level, or when you restart. Defaults are 3 lives, 5 levels, and 8 platforms.

| Setting | Default | Range |
| --- | --- | --- |
| Lives | 3 | 1–20 |
| Levels to beat | 5 | 1–20 |
| Platforms per level | 8 | 4–40 |

Platform count includes the start pad. The last platform is the goal.

## Run

Open this folder in Godot 4, or:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path games/dont-touch-the-lava
```

Headless check (prints `playtest ok` when the platform count matches):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path games/dont-touch-the-lava --quit-after 120 -- --playtest
```
