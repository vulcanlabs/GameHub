#!/usr/bin/env bash
# Imports the PBR maps with the settings a tiled 3D surface needs, without opening the editor.
#
#   games/krx-ball-cleanup/tools/import_assets.sh
#
# Godot's default for a new .jpg is lossless with no mipmaps. On a 2K tiled floor that shimmers at a distance
# and costs about 16 MB of video memory per map. This switches every map under assets/textures to
# VRAM compression with mipmaps, and marks the normal maps as normal maps.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

# First pass writes a .import file beside any map that does not have one yet.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

find assets/textures -name '*.jpg.import' -print0 | while IFS= read -r -d '' file; do
	perl -pi -e 's/^compress\/mode=\d+/compress\/mode=2/; s/^mipmaps\/generate=\w+/mipmaps\/generate=true/' "$file"
	case "$file" in
		*_NormalGL.jpg.import) perl -pi -e 's/^compress\/normal_map=\d+/compress\/normal_map=1/' "$file" ;;
	esac
done

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

missing=0
find assets/textures -name '*.jpg.import' -print0 | while IFS= read -r -d '' file; do
	if ! grep -q '"vram_texture": true' "$file"; then
		echo "not VRAM compressed: $file"
		missing=1
	fi
done
echo "imported $(find assets/textures -name '*.jpg.import' | wc -l | tr -d ' ') maps"
