#!/usr/bin/env python3
"""Composite background preview PNGs into one labeled sheet."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = Path(__file__).resolve().parent
INPUT_DIR = SCRIPT_DIR
OUTPUT_PATH = SCRIPT_DIR / "composite_sheet.png"

THUMB_WIDTH = 480
CAPTION_HEIGHT = 36
PADDING = 12
BG_COLOR = (24, 24, 28)
CAPTION_BG = (12, 12, 16)
CAPTION_FG = (235, 235, 235)
GRID_COLS = 7


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
	for path in (
		"/System/Library/Fonts/Supplemental/Arial.ttf",
		"/System/Library/Fonts/Helvetica.ttc",
		"/Library/Fonts/Arial.ttf",
	):
		font_path = Path(path)
		if font_path.exists():
			return ImageFont.truetype(str(font_path), size=size)
	return ImageFont.load_default()


def thumb_size(source: Image.Image) -> tuple[int, int]:
	scale = THUMB_WIDTH / source.width
	height = max(1, round(source.height * scale))
	return THUMB_WIDTH, height


def collect_images(input_dir: Path) -> list[tuple[str, Path]]:
	files = sorted(
		path
		for path in input_dir.glob("*.png")
		if path.name not in {"composite_sheet.png"}
	)
	current = input_dir / "current_parallax_sky_Original.png"
	if current in files:
		files.remove(current)
		files.insert(0, current)
	return [(path.stem, path) for path in files]


def choose_grid(count: int) -> tuple[int, int]:
	cols = min(GRID_COLS, max(1, count))
	rows = math.ceil(count / cols)
	return cols, rows


def composite_sheet(
	input_dir: Path = INPUT_DIR,
	output_path: Path = OUTPUT_PATH,
) -> Path:
	entries = collect_images(input_dir)
	if not entries:
		raise SystemExit(f"No PNG previews found in {input_dir}")

	font = load_font(14)
	cols, rows = choose_grid(len(entries))

	thumbs: list[tuple[str, Image.Image, tuple[int, int]]] = []
	max_thumb_height = 0
	for label, path in entries:
		with Image.open(path) as source:
			source = source.convert("RGBA")
			size = thumb_size(source)
			thumb = source.resize(size, Image.Resampling.LANCZOS)
		max_thumb_height = max(max_thumb_height, thumb.height)
		thumbs.append((label, thumb, size))

	cell_width = THUMB_WIDTH + PADDING
	cell_height = max_thumb_height + CAPTION_HEIGHT + PADDING
	sheet_width = cols * cell_width + PADDING
	sheet_height = rows * cell_height + PADDING

	sheet = Image.new("RGB", (sheet_width, sheet_height), BG_COLOR)
	draw = ImageDraw.Draw(sheet)

	for index, (label, thumb, _size) in enumerate(thumbs):
		col = index % cols
		row = index // cols
		x = PADDING + col * cell_width
		y = PADDING + row * cell_height

		thumb_x = x + (THUMB_WIDTH - thumb.width) // 2
		thumb_y = y
		sheet.paste(thumb, (thumb_x, thumb_y), thumb)

		caption_y = y + max_thumb_height
		draw.rectangle(
			[x, caption_y, x + THUMB_WIDTH, caption_y + CAPTION_HEIGHT],
			fill=CAPTION_BG,
		)
		draw.text(
			(x + 8, caption_y + 10),
			label,
			fill=CAPTION_FG,
			font=font,
		)

	output_path.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(output_path, optimize=True)
	print(f"Wrote {output_path} ({sheet_width}x{sheet_height}, {len(entries)} previews)")
	return output_path


if __name__ == "__main__":
	composite_sheet()
