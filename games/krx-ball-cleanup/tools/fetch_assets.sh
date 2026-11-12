#!/usr/bin/env bash
# Downloads the third-party assets this project uses, straight from their official sources.
# Every file fetched here is listed in ASSET_CREDITS.md with its licence.
#
#   games/krx-ball-cleanup/tools/fetch_assets.sh
#
# Safe to run again: sets that are already unpacked are skipped.
# After a fresh download run tools/import_assets.sh so Godot imports the maps with the right settings.
set -euo pipefail

cd "$(dirname "$0")/.."
TEXTURES=assets/textures
FONTS=assets/fonts
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ambientCG 2K JPG PBR sets (CC0 1.0). https://ambientcg.com/view?id=<id>
AMBIENTCG_SETS=(
	Tiles133B    # floor: worn off-white ceramic, 12 x 12 tiles per image
	Tiles133A    # walls and pillars: clean white ceramic, same layout
	Tiles132B    # accent bands, pit lining: worn blue pool tile
	Concrete034  # ceiling slab, pit floor
	Metal012     # brushed steel: beams, ducts, door, vacuum nozzle
	Plastic018B  # scratched plastic: vacuum body
)

# Only the maps the materials read. Displacement and the DirectX normal map are left out.
KEEP_MAPS="Color NormalGL Roughness AmbientOcclusion Metalness"

for id in "${AMBIENTCG_SETS[@]}"; do
	dest="$TEXTURES/$id"
	if [ -f "$dest/${id}_2K-JPG_Color.jpg" ]; then
		echo "have $id"
		continue
	fi
	echo "fetch $id"
	curl -fsSL --max-time 300 -o "$TMP/$id.zip" "https://ambientcg.com/get?file=${id}_2K-JPG.zip"
	mkdir -p "$TMP/$id" "$dest"
	unzip -oq "$TMP/$id.zip" -d "$TMP/$id"
	for map in $KEEP_MAPS; do
		src="$TMP/$id/${id}_2K-JPG_${map}.jpg"
		if [ -f "$src" ]; then
			cp "$src" "$dest/"
		fi
	done
done

# Barlow Condensed (SIL Open Font License 1.1), from the Google Fonts repository.
FONT_BASE="https://raw.githubusercontent.com/google/fonts/main/ofl/barlowcondensed"
mkdir -p "$FONTS"
for file in BarlowCondensed-SemiBold.ttf BarlowCondensed-Bold.ttf OFL.txt; do
	if [ -f "$FONTS/$file" ]; then
		echo "have $file"
		continue
	fi
	echo "fetch $file"
	curl -fsSL --max-time 120 -o "$FONTS/$file" "$FONT_BASE/$file"
done

echo "done"
