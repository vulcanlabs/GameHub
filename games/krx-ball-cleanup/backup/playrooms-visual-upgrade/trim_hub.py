from pathlib import Path

p = Path("/home/chris/development/GameHub/games/krx-ball-cleanup/scripts/gameplay/level_1_hub.gd")
lines = p.read_text().splitlines(True)
# keep 1-820, 1049-1061 (_loose_ball), 1132-end (_cyl onward)
kept = lines[0:820] + ["\n"] + lines[1048:1061] + ["\n"] + lines[1131:]
p.write_text("".join(kept))
print("lines before", len(lines), "after", len(kept))
