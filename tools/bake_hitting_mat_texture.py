#!/usr/bin/env python3
"""Downscale a source image to a 16x16 hitting-mat tile (nearest-neighbor)."""

from __future__ import annotations

import sys
from pathlib import Path

try:
	from PIL import Image, ImageEnhance
except ImportError:
	print("Pillow is required: pip install Pillow", file=sys.stderr)
	sys.exit(1)

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = PROJECT_ROOT / "Screenshot 2026-07-06 at 11.57.44 PM.png"
FALLBACK_SOURCE = (
	Path.home()
	/ ".cursor/projects/Users-pbrown-Desktop-golf-incremental/assets"
	/ "Screenshot_2026-07-06_at_11.57.44_PM-18d9b9ae-0760-4c4c-bdc5-fd61cf1a715a.png"
)
OUTPUT = PROJECT_ROOT / "assets/sprites/range/hitting_mat.png"
TILE_SIZE = 16
BRIGHTNESS = 2.25


def resolve_source() -> Path:
	if len(sys.argv) > 1:
		return Path(sys.argv[1]).expanduser().resolve()
	if DEFAULT_SOURCE.exists():
		return DEFAULT_SOURCE
	if FALLBACK_SOURCE.exists():
		return FALLBACK_SOURCE
	raise FileNotFoundError("No source image found. Pass a path as the first argument.")


def main() -> int:
	source = resolve_source()
	output = OUTPUT
	output.parent.mkdir(parents=True, exist_ok=True)

	with Image.open(source) as img:
		rgb = img.convert("RGB")
		tile = rgb.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.NEAREST)
		tile = ImageEnhance.Brightness(tile).enhance(BRIGHTNESS)
		tile.save(output)

	print(f"Source: {source}")
	print(f"Output: {output} ({TILE_SIZE}x{TILE_SIZE})")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
