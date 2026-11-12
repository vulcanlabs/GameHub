# Asset credits

Every third-party file in this project, where it came from, and its licence.
`tools/fetch_assets.sh` downloads exactly these files from the URLs below.

## Textures

All from [ambientCG](https://ambientcg.com). Author: Lennart Demes / ambientCG.com.
Licence: [Creative Commons CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) (public domain, no attribution required).
Each set is the 2K JPG download; only the listed maps are kept. Stored in `assets/textures/<id>/`.

| Set | Used for | Maps kept | Page | Download |
| --- | --- | --- | --- | --- |
| Tiles133B | Floor: worn off-white ceramic tile | Color, NormalGL, Roughness, AmbientOcclusion | https://ambientcg.com/view?id=Tiles133B | https://ambientcg.com/get?file=Tiles133B_2K-JPG.zip |
| Tiles133A | Walls and pillars: white ceramic tile | Color, NormalGL, Roughness, AmbientOcclusion | https://ambientcg.com/view?id=Tiles133A | https://ambientcg.com/get?file=Tiles133A_2K-JPG.zip |
| Tiles132B | Blue accent bands, pit lining and kerb | Color, NormalGL, Roughness, AmbientOcclusion | https://ambientcg.com/view?id=Tiles132B | https://ambientcg.com/get?file=Tiles132B_2K-JPG.zip |
| Concrete034 | Ceiling slab, pit floor | Color, NormalGL, Roughness | https://ambientcg.com/view?id=Concrete034 | https://ambientcg.com/get?file=Concrete034_2K-JPG.zip |
| Metal012 | Beams, ducts, pipes, door, vacuum wand | Color, NormalGL, Roughness, Metalness | https://ambientcg.com/view?id=Metal012 | https://ambientcg.com/get?file=Metal012_2K-JPG.zip |
| Plastic018B | Vacuum body and yellow trim | Color, NormalGL, Roughness | https://ambientcg.com/view?id=Plastic018B | https://ambientcg.com/get?file=Plastic018B_2K-JPG.zip |

The materials in `assets/materials/` were written for this project and only reference these maps.

## Fonts

| File | Author | Licence | Source |
| --- | --- | --- | --- |
| `assets/fonts/BarlowCondensed-SemiBold.ttf` | The Barlow Project Authors (Jeremy Tribby) | [SIL Open Font License 1.1](https://openfontlicense.org), copy in `assets/fonts/OFL.txt` | https://github.com/google/fonts/tree/main/ofl/barlowcondensed |
| `assets/fonts/BarlowCondensed-Bold.ttf` | The Barlow Project Authors (Jeremy Tribby) | SIL Open Font License 1.1 | https://github.com/google/fonts/tree/main/ofl/barlowcondensed |

## Made for this project (no third-party source)

| What | Where | Note |
| --- | --- | --- |
| Vacuum model | built in code by `scripts/gameplay/vacuum.gd` | Original design made from primitive shapes. Blender was not available on the build machine, so there is no `.blend` or `.glb` yet. |
| Hall, pit, door, lights, pipes | built in code by `scripts/gameplay/level_1_hub.gd`, `scripts/interactions/collection_pit.gd` | Original layout. |
| All sounds | synthesised at start-up by `autoload/sfx.gd` | Placeholders. No Freesound file is used: Freesound's original-quality downloads need an account, and every sound needs its own licence check. Drop a file at `assets/audio/<name>.ogg` (or `.wav`, `.mp3`) to replace a placeholder, and add it to this file. Names: `vacuum_motor`, `vacuum_air`, `ball_pop`, `ball_pour`, `warn_full`, `step_tile`, `room_hum`, `ui_click`, `unlock`. |

## Not downloaded yet

Poly Haven textures and models (carpet, wallpaper, ceiling, props) and the ambientCG grass and soil sets belong
to Levels 2 to 7, which are not built. Nothing from Poly Haven or Freesound is in this project.
