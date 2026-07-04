#!/usr/bin/env python3
"""Sample fairway atlas and range backdrop greens; recommend tints and atlas recolors.

Usage:
  python3 tools/analyze_ground_colors.py
  python3 tools/analyze_ground_colors.py --output-json report.json
  python3 tools/analyze_ground_colors.py --apply-atlas   # recolor grass tile (0,0)
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ATLAS_PATH = ROOT / "assets/sprites/fairway/grass_plus_atlas.png"
BACKDROP_PATH = ROOT / "assets/sprites/background/range_backdrop.png"

TILE_PX = 16
GRASS_TILE = (0, 0)

# Target recolor for fairway tile (0,0) — yellow-green ramp from backdrop fairway band.
DEFAULT_RECOLOR_MAP: dict[tuple[int, int, int], tuple[int, int, int]] = {
    (99, 171, 63): (98, 177, 0),   # #63ab3f -> #62b100 bright
    (59, 125, 79): (47, 144, 4),   # #3b7d4f -> #2f9004 mid
    (47, 87, 83): (12, 112, 5),    # #2f5753 -> #0c7005 dark (remove teal bias)
}

BANDS = {
    "foliage": (0.35, 0.50),
    "fairway_band": (0.55, 0.72),
    "near_grass": (0.72, 0.95),
}


def rgb_to_hex(rgb: np.ndarray) -> str:
    r, g, b = (int(round(c * 255)) for c in rgb)
    return f"#{r:02x}{g:02x}{b:02x}"


def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    h = hex_str.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def luminance(rgb: np.ndarray) -> float:
    return float(0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2])


def is_greenish(rgb: np.ndarray, min_g: float = 0.12) -> bool:
    return rgb[1] > rgb[0] and rgb[1] > rgb[2] and rgb[1] >= min_g


def sample_band(img: np.ndarray, y_start_pct: float, y_end_pct: float) -> np.ndarray:
    h = img.shape[0]
    y0 = int(h * y_start_pct)
    y1 = int(h * y_end_pct)
    region = img[y0:y1, :, :3].reshape(-1, 3)
    alpha = img[y0:y1, :, 3].reshape(-1)
    mask = (alpha > 0.5) & np.array([is_greenish(p) for p in region])
    return region[mask]


def percentile_rgb(pixels: np.ndarray, pct: float) -> np.ndarray:
    if len(pixels) == 0:
        return np.zeros(3, dtype=np.float32)
    lum = np.array([luminance(p) for p in pixels])
    idx = int(len(lum) * pct / 100)
    idx = min(idx, len(lum) - 1)
    return pixels[np.argsort(lum)[idx]]


def atlas_tile_colors(img: Image.Image, col: int, row: int) -> tuple[np.ndarray, list[tuple[int, int, int]]]:
    rgba = np.array(img.convert("RGBA"))
    x0, y0 = col * TILE_PX, row * TILE_PX
    tile = rgba[y0 : y0 + TILE_PX, x0 : x0 + TILE_PX]
    rgb = tile[:, :, :3].reshape(-1, 3)
    alpha = tile[:, :, 3].reshape(-1)
    opaque = rgb[alpha > 128]
    mean = opaque.mean(axis=0) / 255.0 if len(opaque) else np.zeros(3)
    uniq = [tuple(c) for c in np.unique(opaque.astype(np.uint8), axis=0)]
    return mean, uniq


def recommend_tint(atlas_mean: np.ndarray, target: np.ndarray) -> np.ndarray:
    return target / np.maximum(atlas_mean, 0.01)


def apply_atlas_recolor(path: Path, recolor_map: dict[tuple[int, int, int], tuple[int, int, int]]) -> None:
    img = Image.open(path)
    rgba = np.array(img.convert("RGBA"))
    col, row = GRASS_TILE
    x0, y0 = col * TILE_PX, row * TILE_PX
    tile = rgba[y0 : y0 + TILE_PX, x0 : x0 + TILE_PX]
    for y in range(TILE_PX):
        for x in range(TILE_PX):
            r, g, b, a = tile[y, x]
            key = (int(r), int(g), int(b))
            if key in recolor_map:
                nr, ng, nb = recolor_map[key]
                tile[y, x] = (nr, ng, nb, a)
    rgba[y0 : y0 + TILE_PX, x0 : x0 + TILE_PX] = tile

    out = Image.fromarray(rgba, mode="RGBA")
    if img.mode == "P":
        out = out.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
    out.save(path)
    print(f"Applied atlas recolor to {path}")


def analyze(apply_atlas: bool = False) -> dict:
    if apply_atlas:
        apply_atlas_recolor(ATLAS_PATH, DEFAULT_RECOLOR_MAP)

    atlas_img = Image.open(ATLAS_PATH)
    atlas_mean, atlas_unique = atlas_tile_colors(atlas_img, *GRASS_TILE)
    backdrop = np.array(Image.open(BACKDROP_PATH).convert("RGBA"), dtype=np.float32) / 255.0

    band_stats = {}
    for name, (y0, y1) in BANDS.items():
        pixels = sample_band(backdrop, y0, y1)
        band_stats[name] = {
            "count": int(len(pixels)),
            "mean": pixels.mean(axis=0).tolist() if len(pixels) else [0, 0, 0],
            "p75": percentile_rgb(pixels, 75).tolist(),
            "p25": percentile_rgb(pixels, 25).tolist(),
        }

    fairway = band_stats["fairway_band"]
    foliage = band_stats["foliage"]
    p75 = np.array(fairway["p75"], dtype=np.float32)
    p25 = np.array(fairway["p25"], dtype=np.float32)
    foliage_p75 = np.array(foliage["p75"], dtype=np.float32)
    foliage_mean = np.array(foliage["mean"], dtype=np.float32)

    fairway_light = recommend_tint(atlas_mean, p75)
    fairway_dark = recommend_tint(atlas_mean, p25)
    # Hills tint: scale backdrop foliage pixels toward day target using mean pixel as base.
    hills_tint = np.clip(foliage_p75 / np.maximum(foliage_mean, 0.01), 0.5, 1.5)

    report = {
        "atlas_tile_mean": atlas_mean.tolist(),
        "atlas_unique_rgb": [list(int(x) for x in c) for c in atlas_unique],
        "atlas_recolor_map": {
            rgb_to_hex(np.array(k) / 255.0): rgb_to_hex(np.array(v) / 255.0)
            for k, v in DEFAULT_RECOLOR_MAP.items()
        },
        "backdrop_bands": band_stats,
        "recommended_day_tints": {
            "fairway_light": [round(float(c), 3) for c in fairway_light],
            "fairway_dark": [round(float(c), 3) for c in fairway_dark],
            "hills": [round(float(c), 3) for c in hills_tint],
        },
        "effective_with_tints": {
            "light_stripe": (atlas_mean * fairway_light).tolist(),
            "dark_stripe": (atlas_mean * fairway_dark).tolist(),
        },
    }

    print("=== Fairway + Backdrop Color Analysis ===\n")
    print(f"Atlas tile (0,0) mean: {tuple(round(x, 3) for x in atlas_mean)}")
    print(f"Atlas unique colors: {[rgb_to_hex(np.array(c)/255.0) for c in atlas_unique]}\n")

    for name, stats in band_stats.items():
        m = stats["mean"]
        print(f"Backdrop {name}:")
        print(f"  mean {tuple(round(x, 3) for x in m)}  p75 {tuple(round(x, 3) for x in stats['p75'])}")

    rec = report["recommended_day_tints"]
    print("\nRecommended day palette tints (atlas * tint = target):")
    print(f"  fairway_light: {rec['fairway_light']}")
    print(f"  fairway_dark:  {rec['fairway_dark']}")
    print(f"  hills:         {rec['hills']}")

    eff = report["effective_with_tints"]
    print("\nEffective ground stripes:")
    print(f"  light: {tuple(round(x, 3) for x in eff['light_stripe'])}")
    print(f"  dark:  {tuple(round(x, 3) for x in eff['dark_stripe'])}")
    print(f"  targets p75/p25: {tuple(round(x, 3) for x in p75)} / {tuple(round(x, 3) for x in p25)}")

    return report


def scale_phase_color(old_day: tuple[float, float, float], new_day: tuple[float, float, float], old_val: tuple[float, float, float]) -> list[float]:
    """Scale a phase key proportionally from old day reference to new day reference."""
    result = []
    for o_d, n_d, o_v in zip(old_day, new_day, old_val):
        if abs(o_d) < 0.001:
            result.append(round(n_d, 3))
        else:
            result.append(round(o_v * (n_d / o_d), 3))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-json", type=Path, help="Write JSON report")
    parser.add_argument("--apply-atlas", action="store_true", help="Recolor grass atlas tile")
    args = parser.parse_args()

    report = analyze(apply_atlas=args.apply_atlas)

    # Old vs new day reference for proportional phase scaling (from prior palette).
    old_light = (0.54, 0.76, 0.44)
    old_dark = (0.36, 0.52, 0.28)
    old_hills = (0.35, 0.55, 0.38)
    new_light = tuple(report["recommended_day_tints"]["fairway_light"])
    new_dark = tuple(report["recommended_day_tints"]["fairway_dark"])
    new_hills = tuple(report["recommended_day_tints"]["hills"])

    phases = {
        "midnight": {"light": (0.38, 0.52, 0.42), "dark": (0.28, 0.40, 0.32), "hills": (0.12, 0.18, 0.16)},
        "dawn": {"light": (0.48, 0.68, 0.40), "dark": (0.32, 0.46, 0.27), "hills": (0.30, 0.46, 0.36)},
        "dusk": {"light": (0.50, 0.68, 0.38), "dark": (0.34, 0.48, 0.27), "hills": (0.36, 0.46, 0.32)},
        "night": {"light": (0.44, 0.62, 0.48), "dark": (0.32, 0.46, 0.36), "hills": (0.18, 0.28, 0.22)},
    }
    scaled = {}
    for phase, vals in phases.items():
        scaled[phase] = {
            "fairway_light": scale_phase_color(old_light, new_light, vals["light"]),
            "fairway_dark": scale_phase_color(old_dark, new_dark, vals["dark"]),
            "hills": scale_phase_color(old_hills, new_hills, vals["hills"]),
        }
    report["scaled_phase_tints"] = scaled
    report["recommended_day_tints"]["fairway_base"] = [
        round((new_light[i] + new_dark[i]) * 0.5 * atlas_mean[i] if False else (new_light[i] + new_dark[i]) * 0.25, 3)
        for i in range(3)
    ]
    # fairway_base: average of light/dark effective colors / 2 for tint keys
    atlas_mean = np.array(report["atlas_tile_mean"])
    eff_avg = (atlas_mean * np.array(new_light) + atlas_mean * np.array(new_dark)) * 0.25
    report["recommended_day_tints"]["fairway_base"] = [round(float(c), 3) for c in eff_avg * 2 / np.maximum(atlas_mean, 0.01)]

    if args.output_json:
        args.output_json.write_text(json.dumps(report, indent=2))
        print(f"\nWrote {args.output_json}")

    print("\nScaled phase tints (for day_night_palette.gd):")
    for phase, vals in scaled.items():
        print(f"  {phase}: light={vals['fairway_light']} dark={vals['fairway_dark']} hills={vals['hills']}")


if __name__ == "__main__":
    main()
