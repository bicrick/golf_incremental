#!/usr/bin/env python3
"""Batch-recolor iso fairway terrain PNGs to target light/dark/mat means.

Iso-only — does not touch DayNightPalette / 3D fairway.
Preserves relative texture variation (additive mean shift + exact mean lock).

  python3 tools/recolor_iso_fairway.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TERRAIN = ROOT / "assets" / "sprites" / "iso" / "terrain"

## Perspective-sampled iso targets (light/dark/forest).
## Bay mats use authored fairway_mat.png — not regenerated here.
LIGHT_HEX = (0x26, 0x74, 0x08)  # #267408
DARK_HEX = (0x1E, 0x5C, 0x06)  # #1e5c06
## Darker apron beyond the fairway (roughly ~0.6× dark mean).
FOREST_HEX = (0x12, 0x38, 0x04)  # #123804
ALPHA_CUTOFF = 0.5


def hex_to_unit(rgb: tuple[int, int, int]) -> np.ndarray:
	return np.array(rgb, dtype=np.float64) / 255.0


def opaque_mean(rgba: np.ndarray) -> np.ndarray:
	a = rgba[:, :, 3]
	mask = a >= ALPHA_CUTOFF
	if not np.any(mask):
		return np.zeros(3, dtype=np.float64)
	return rgba[:, :, :3][mask].mean(axis=0)


def shift_mean_to(rgba: np.ndarray, target: np.ndarray) -> np.ndarray:
	out = rgba.copy()
	a = out[:, :, 3]
	mask = a >= ALPHA_CUTOFF
	if not np.any(mask):
		return out
	mean = out[:, :, :3][mask].mean(axis=0)
	delta = target - mean
	out[:, :, :3][mask] = np.clip(out[:, :, :3][mask] + delta, 0.0, 1.0)
	mean2 = out[:, :, :3][mask].mean(axis=0)
	scale = np.ones(3, dtype=np.float64)
	for i in range(3):
		if mean2[i] > 1e-6:
			scale[i] = target[i] / mean2[i]
	out[:, :, :3][mask] = np.clip(out[:, :, :3][mask] * scale, 0.0, 1.0)
	## Keep opaque pixels G-dominant.
	rgb = out[:, :, :3]
	g = rgb[:, :, 1]
	r = rgb[:, :, 0]
	b = rgb[:, :, 2]
	bad = mask & ((r > g) | (b > g) | (g <= 0.02))
	if np.any(bad):
		rgb[:, :, 0][bad] = np.minimum(rgb[:, :, 0][bad], g[bad] * 0.85)
		rgb[:, :, 2][bad] = np.minimum(rgb[:, :, 2][bad], g[bad] * 0.85)
		rgb[:, :, 1][bad] = np.maximum(g[bad], 0.03)
		out[:, :, :3] = np.clip(rgb, 0.0, 1.0)
		mean3 = out[:, :, :3][mask].mean(axis=0)
		for i in range(3):
			if mean3[i] > 1e-6:
				out[:, :, i][mask] = np.clip(
					out[:, :, i][mask] * (target[i] / mean3[i]), 0.0, 1.0
				)
	return out


def save_rgba(path: Path, rgba: np.ndarray) -> None:
	img = (np.clip(rgba, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
	Image.fromarray(img, mode="RGBA").save(path)
	mean = opaque_mean(rgba)
	print(
		f"  wrote {path.name} mean="
		f"#{int(mean[0]*255):02x}{int(mean[1]*255):02x}{int(mean[2]*255):02x}"
	)


def _opaque_u8(im: np.ndarray) -> np.ndarray:
	return im[:, :, 3] >= 128


def unify_fairway_silhouettes() -> None:
	"""Force every fairway variant onto one tessellating diamond mask.

	PixelLab variants differ by a few edge texels. Mixed on the TileMap that
	opens 1px gaps — sky shows through as nasty gray/blue speckles.
	"""
	## Light/dark/forest — fairway_mat.png is authored separately.
	paths = sorted(TERRAIN.glob("fairway_light_*.png"))
	paths += sorted(TERRAIN.glob("fairway_dark_*.png"))
	paths += sorted(TERRAIN.glob("fairway_forest_*.png"))
	if not paths:
		return
	imgs = [np.asarray(Image.open(p).convert("RGBA"), dtype=np.uint8) for p in paths]
	target = np.zeros(imgs[0].shape[:2], dtype=bool)
	for im in imgs:
		target |= _opaque_u8(im)
	print(f"Unify silhouettes → {int(target.sum())} opaque texels")
	for path, im in zip(paths, imgs):
		out = _fill_to_mask(im, target)
		Image.fromarray(out, mode="RGBA").save(path)
		print(f"  silhouette {path.name}")
def _fill_to_mask(im: np.ndarray, target: np.ndarray) -> np.ndarray:
	out = im.copy()
	filled = _opaque_u8(out)
	out[~filled, 0:3] = 0
	pending = list(zip(*np.where(target & ~filled)[::-1]))
	guard = 0
	while pending and guard < 10000:
		guard += 1
		nxt: list[tuple[int, int]] = []
		progress = False
		for x, y in pending:
			samples: list[np.ndarray] = []
			for nx, ny in (
				(x - 1, y),
				(x + 1, y),
				(x, y - 1),
				(x, y + 1),
				(x - 1, y - 1),
				(x + 1, y - 1),
				(x - 1, y + 1),
				(x + 1, y + 1),
			):
				if 0 <= nx < out.shape[1] and 0 <= ny < out.shape[0] and filled[ny, nx]:
					samples.append(out[ny, nx, :3])
			if samples:
				out[y, x, :3] = np.mean(samples, axis=0).round().astype(np.uint8)
				out[y, x, 3] = 255
				filled[y, x] = True
				progress = True
			else:
				nxt.append((x, y))
		pending = nxt
		if not progress:
			break
	if pending:
		mean = (
			out[filled, :3].mean(axis=0).round().astype(np.uint8)
			if np.any(filled)
			else np.array([0x26, 0x74, 0x08], dtype=np.uint8)
		)
		for x, y in pending:
			out[y, x, :3] = mean
			out[y, x, 3] = 255
	out[~target] = 0
	return out


def main() -> None:
	light_t = hex_to_unit(LIGHT_HEX)
	dark_t = hex_to_unit(DARK_HEX)
	forest_t = hex_to_unit(FOREST_HEX)

	lights = sorted(TERRAIN.glob("fairway_light_*.png"))
	if not lights:
		raise SystemExit(f"no fairway_light_*.png under {TERRAIN}")

	print(
		f"Recolor {len(lights)} variants → light=#{LIGHT_HEX[0]:02x}{LIGHT_HEX[1]:02x}{LIGHT_HEX[2]:02x} "
		f"dark=#{DARK_HEX[0]:02x}{DARK_HEX[1]:02x}{DARK_HEX[2]:02x} "
		f"forest=#{FOREST_HEX[0]:02x}{FOREST_HEX[1]:02x}{FOREST_HEX[2]:02x} "
		f"(mats skipped — authored fairway_mat.png)"
	)
	for light_path in lights:
		idx = light_path.stem.rsplit("_", 1)[-1]
		rgba = np.asarray(Image.open(light_path).convert("RGBA"), dtype=np.float64) / 255.0
		light = shift_mean_to(rgba, light_t)
		dark = shift_mean_to(light.copy(), dark_t)
		forest = shift_mean_to(dark.copy(), forest_t)

		save_rgba(TERRAIN / f"fairway_light_{idx}.png", light)
		save_rgba(TERRAIN / f"fairway_dark_{idx}.png", dark)
		save_rgba(TERRAIN / f"fairway_forest_{idx}.png", forest)

	unify_fairway_silhouettes()
	print("done")


if __name__ == "__main__":
	main()
