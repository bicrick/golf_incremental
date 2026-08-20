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

# Godot resamples the project icon with a blurry filter. Overwrite favicons
# from the 32x32 pixel source using nearest-neighbor so they stay crisp.
ICON_SRC="$ROOT/assets/ui/range_rat_icon.png"
if [[ ! -f "$ICON_SRC" ]]; then
  echo "Missing $ICON_SRC" >&2
  exit 1
fi
python3 - "$ICON_SRC" "$OUT_DIR" <<'PY'
from pathlib import Path
import sys
from PIL import Image

src = Image.open(sys.argv[1]).convert("RGBA")
out_dir = Path(sys.argv[2])
if src.size != (32, 32):
    raise SystemExit(f"export_web: expected 32x32 icon, got {src.size}")
src.resize((128, 128), Image.NEAREST).save(out_dir / "index.icon.png", "PNG")
src.resize((180, 180), Image.NEAREST).save(out_dir / "index.apple-touch-icon.png", "PNG")
print(f"==> Wrote nearest-neighbor favicons from {src.size} source")
PY

# Capture Godot's AudioContext at construction and resume on first page gesture.
python3 - "$OUT_DIR/index.html" <<'PY'
from pathlib import Path
import sys

html_path = Path(sys.argv[1])
text = html_path.read_text()
marker = '<script src="index.js"></script>'
snippet = '''<script src="index.js"></script>
		<script>
(function () {
	if (window.__golfAudioUnlockInstalled) {
		return;
	}
	var Orig = window.AudioContext || window.webkitAudioContext;
	window.__golfResumeAudio = function () {
		var ctx = window.__golfAudioCtx;
		if (ctx && ctx.state !== "running" && ctx.resume) {
			ctx.resume();
		}
	};
	["pointerdown", "touchstart", "keydown", "mousedown"].forEach(function (type) {
		window.addEventListener(type, window.__golfResumeAudio, { capture: true, passive: true });
	});
	if (Orig) {
		try {
			class GolfAudioContext extends Orig {
				constructor(opts) {
					super(opts);
					window.__golfAudioCtx = this;
				}
			}
			window.AudioContext = GolfAudioContext;
			if (window.webkitAudioContext) {
				window.webkitAudioContext = GolfAudioContext;
			}
			window.__golfAudioUnlockInstalled = true;
		} catch (err) {}
	}
})();
		</script>'''
if marker not in text:
    raise SystemExit("export_web: index.html missing index.js script tag")
if "__golfAudioUnlockInstalled" not in text:
    html_path.write_text(text.replace(marker, snippet, 1))
PY

# Confirm the loader stayed Range Rat branded (no Godot wordmark/robot splash).
python3 - "$OUT_DIR" "$ICON_SRC" <<'PY'
from pathlib import Path
import sys
from PIL import Image

out_dir = Path(sys.argv[1])
icon = Image.open(sys.argv[2]).convert("RGBA")
html = (out_dir / "index.html").read_text()
splash_path = out_dir / "index.png"
if not splash_path.is_file():
    raise SystemExit("export_web: missing index.png boot splash")
splash = Image.open(splash_path).convert("RGBA")
lower = html.lower()
if "godot" in html and "range rat" not in html.lower():
    raise SystemExit("export_web: index.html lost Range Rat title")
if "game engine" in lower or "godot.svg" in lower or "godot logo" in lower:
    raise SystemExit("export_web: Godot branding still visible in index.html")
if "status-title" not in html or "Range Rat" not in html:
    raise SystemExit("export_web: custom Range Rat HTML shell was not applied")
if splash.size != icon.size:
    raise SystemExit(f"export_web: splash {splash.size} != icon {icon.size}")
if list(splash.getdata()) != list(icon.getdata()):
    raise SystemExit("export_web: index.png is not the Range Rat icon")
print("==> Branded loader OK (Range Rat icon splash, no Godot wordmark)")
PY

echo "==> Export complete"
du -sh "$OUT_DIR" "$OUT_DIR"/*.pck "$OUT_DIR"/*.wasm "$OUT_DIR/audio" 2>/dev/null || true
ls -lah "$OUT_DIR" | head -40
