#!/usr/bin/env bash
# Installs a CC0 production art pack into godot/assets/production/<pack> and
# regenerates the runtime asset manifest used by ReleaseAssetRegistry.
#
# Usage:
#   scripts/install_production_packs.sh medieval_village ~/Downloads/Medieval-Village-MegaKit.zip
#   scripts/install_production_packs.sh nature           ~/Downloads/Stylized-Nature-MegaKit.zip
#   scripts/install_production_packs.sh characters       ~/Downloads/Universal-Base-Characters.zip
#
# Valid pack ids are the folders under godot/assets/production/:
#   medieval_village nature characters buildings_extra
#   characters_extra animals crops creatures
#
# GLB is preferred: it embeds its textures, so the pack ships as one file per
# model. GLTF packs are also supported as long as .bin and texture files sit
# next to the .gltf file.
set -euo pipefail

pack_id="${1:-}"
archive="${2:-}"
if [ -z "$pack_id" ] || [ -z "$archive" ]; then
  sed -n '2,18p' "$0"
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$repo_root/godot/assets/production/$pack_id"
if [ ! -d "$dest" ]; then
  echo "Unknown pack id '$pack_id'. Existing packs:" >&2
  ls -1 "$repo_root/godot/assets/production" >&2
  exit 1
fi
if [ ! -f "$archive" ]; then
  echo "Archive not found: $archive" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Extracting $archive"
unzip -q "$archive" -d "$tmp"

count=0
while IFS= read -r -d '' file; do
  rel="${file#$tmp/}"
  mkdir -p "$dest/$(dirname "$rel")"
  cp "$file" "$dest/$rel"
  count=$((count + 1))
done < <(find "$tmp" -type f \( -iname '*.glb' -o -iname '*.gltf' -o -iname '*.bin' \
          -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.tga' \) -print0)

echo "Installed $count files into $dest"

godot_bin="${GODOT_BIN:-godot}"
if command -v "$godot_bin" >/dev/null 2>&1; then
  "$godot_bin" --headless --path "$repo_root/godot" --import
  "$godot_bin" --headless --path "$repo_root/godot" --script res://qa/generate_asset_manifest.gd
  echo "Now run the QA gate: $godot_bin --headless --path godot --script res://qa/headless_qa.gd"
else
  echo "Godot not found (set GODOT_BIN). Import and manifest generation were skipped."
fi
