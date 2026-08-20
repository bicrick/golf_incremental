#!/usr/bin/env bash
# Export Godot web build (non-threaded) and stage OGG BGM for golf.bicrick.com.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT_DIR="$ROOT/export/web"
PRESET_EXAMPLE="$ROOT/export_presets.cfg.example"
PRESET_CFG="$ROOT/export_presets.cfg"
MUSIC_SRC="$ROOT/assets/audio/music"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary not found/executable at: $GODOT" >&2
  exit 1
fi

if [[ ! -f "$PRESET_EXAMPLE" ]]; then
  echo "Missing $PRESET_EXAMPLE" >&2
  exit 1
fi

cp "$PRESET_EXAMPLE" "$PRESET_CFG"
mkdir -p "$OUT_DIR"
# Prevent Godot from importing deploy artifacts back into the project/PCK.
printf '# Deploy output only — not part of the Godot project.\n' > "$ROOT/export/.gdignore"

echo "==> Exporting Web preset to $OUT_DIR"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT_DIR/index.html"

echo "==> Copying OGG BGM into $OUT_DIR/audio/"
mkdir -p "$OUT_DIR/audio"
shopt -s nullglob
ogg_files=("$MUSIC_SRC"/*.ogg)
if [[ ${#ogg_files[@]} -eq 0 ]]; then
  echo "No OGG files found in $MUSIC_SRC" >&2
  exit 1
fi
cp "${ogg_files[@]}" "$OUT_DIR/audio/"
# Never leave Godot .import sidecars next to deploy audio.
rm -f "$OUT_DIR"/audio/*.import "$OUT_DIR"/*.import

# Keep deploy scaffolding next to the export (do not wipe these on re-export).
for f in vercel.json package.json README.md .gitignore; do
  if [[ -f "$ROOT/export/web-deploy/$f" ]]; then
    cp "$ROOT/export/web-deploy/$f" "$OUT_DIR/$f"
  fi
done

echo "==> Export complete"
du -sh "$OUT_DIR" "$OUT_DIR"/*.pck "$OUT_DIR"/*.wasm "$OUT_DIR/audio" 2>/dev/null || true
ls -lah "$OUT_DIR" | head -40
