"""v8 'The Road' — a hand-drawn parchment map of the five ranges (480x270).

The dotted route and the rat token are drawn live in Godot; this is the paper.
Run: python3 tools/art/draw_tour_map.py
"""
from __future__ import annotations

import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites", "tour", "map.png")
W, H = 480, 270
rnd = random.Random(8)

PAPER = (238, 223, 188)
PAPER_D = (222, 204, 164)
PAPER_DD = (196, 172, 128)
INK = (74, 56, 52)
INK_SOFT = (128, 104, 88)
SEA = (150, 190, 196)
SEA_D = (120, 164, 176)
GRASS = (160, 186, 112)
GRASS_D = (128, 160, 92)
SAND = (228, 176, 120)
SAND_D = (204, 140, 96)
SNOW = (248, 248, 250)
ROCK = (150, 140, 150)

STOPS = {
    "barley": (96, 206),
    "cliffs": (70, 124),
    "mesa": (214, 162),
    "frost": (322, 92),
    "edge": (418, 50),
}

img = Image.new("RGBA", (W, H), PAPER + (255,))
px = img.load()


def noise(x: float, y: float, s: float) -> float:
    return (math.sin(x * 0.071 * s + math.cos(y * 0.053 * s) * 2.1) +
            math.sin(y * 0.083 * s + math.sin(x * 0.041 * s) * 1.7)) * 0.25 + 0.5


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dith(x: int, y: int, t: float) -> bool:
    return t * 16 > BAYER[y % 4][x % 4] + 0.5


# Paper grain + vignette.
for y in range(H):
    for x in range(W):
        dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
        v = max(0.0, (dx * dx + dy * dy) - 0.45) * 0.9
        n = noise(x, y, 3.0)
        c = PAPER
        if dith(x, y, v):
            c = PAPER_D
        if dith(x, y, v - 0.35):
            c = PAPER_DD
        if n > 0.82 and rnd.random() < 0.3:
            c = PAPER_D
        px[x, y] = c + (255,)


def region(fn, col, col_d, edge=INK_SOFT):
    inside = [[fn(x, y) for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if not inside[y][x]:
                continue
            border = any(not inside[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                         if 0 <= x + dx < W and 0 <= y + dy < H)
            if border:
                px[x, y] = edge + (255,)
            else:
                px[x, y] = (col_d if dith(x, y, noise(x, y, 2.0) - 0.35) else col) + (255,)


def ell(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1.0 + 0.5 * (noise(x, y, 5.0) - 0.5) + 0.25 * (noise(y, x, 11.0) - 0.5)


# The sea along the left, with wave ticks.
def sea(x, y):
    coast = 44 + 14 * math.sin(y * 0.045) + 8 * math.sin(y * 0.13 + 1.0)
    return x < coast and y > 60
region(sea, SEA, SEA_D, INK)
for i in range(26):
    x, y = rnd.randint(4, 40), rnd.randint(70, 262)
    if sea(x + 6, y):
        for k in range(4):
            px[x + k, y + (1 if k in (1, 2) else 0)] = SEA_D + (255,) if k % 3 else INK_SOFT + (255,)

# Meadow blob around Barley's.
region(lambda x, y: ell(x, y, 110, 214, 74, 48) and not sea(x, y), GRASS, GRASS_D)
# Desert around the Mesa.
region(lambda x, y: ell(x, y, 222, 170, 78, 42), SAND, SAND_D)
# Snowfields up by Frostpine.
region(lambda x, y: ell(x, y, 330, 94, 72, 38), SNOW, (226, 232, 242))
# The cloud sea at the Edge.
region(lambda x, y: ell(x, y, 428, 58, 62, 36), (250, 236, 240), (240, 214, 226))


def tri(cx, cy, w, h, fill, cap=None):
    for yy in range(h):
        half = int(w * yy / h / 2)
        for xx in range(-half, half + 1):
            c = fill
            if xx > 0:
                c = tuple(int(v * 0.86) for v in fill)
            if cap and yy < h * 0.35:
                c = cap
            px[cx + xx, cy - h + yy] = c + (255,)
    for yy in range(h):
        half = int(w * yy / h / 2)
        px[cx - half - 1, cy - h + yy] = INK + (255,)
        px[cx + half + 1, cy - h + yy] = INK + (255,)
    for xx in range(-w // 2 - 1, w // 2 + 2):
        px[cx + xx, cy] = INK + (255,)


def tree(cx, cy):
    tri(cx, cy, 6, 8, (94, 140, 80))
    px[cx, cy + 1] = INK + (255,)


def cactus(cx, cy):
    for yy in range(7):
        px[cx, cy - yy] = (92, 140, 84, 255)
    for yy in range(3):
        px[cx - 2, cy - 3 - yy] = (92, 140, 84, 255)
        px[cx + 2, cy - 2 - yy] = (92, 140, 84, 255)
    px[cx - 1, cy - 3] = (92, 140, 84, 255)
    px[cx + 1, cy - 2] = (92, 140, 84, 255)


# Mountains along the top, snow-capped near Frostpine.
for i, (mx, mh) in enumerate([(250, 26), (272, 34), (298, 30), (350, 38), (376, 28), (240, 18), (395, 22)]):
    tri(mx, 64 + (i % 2) * 4, mh + 8, mh, ROCK, SNOW)
# Mesas.
for mx, my, w in [(180, 150, 22), (256, 176, 18), (232, 138, 14)]:
    for yy in range(8):
        for xx in range(w):
            c = (200, 110, 76) if yy > 2 else (224, 140, 96)
            px[mx + xx, my + yy] = c + (255,)
    for xx in range(-1, w + 1):
        px[mx + xx, my - 1] = INK + (255,)
        px[mx + xx, my + 8] = INK + (255,)
    for yy in range(8):
        px[mx - 1, my + yy] = INK + (255,)
        px[mx + w, my + yy] = INK + (255,)
for _ in range(40):
    x, y = rnd.randint(60, 170), rnd.randint(180, 250)
    if ((x - 110) / 70) ** 2 + ((y - 214) / 44) ** 2 < 0.8 and ((x - 96) ** 2 + (y - 206) ** 2) > 200:
        tree(x, y)
for _ in range(14):
    x, y = rnd.randint(160, 290), rnd.randint(150, 200)
    if ((x - 222) / 74) ** 2 + ((y - 172) / 40) ** 2 < 0.7:
        cactus(x, y)
for _ in range(22):
    x, y = rnd.randint(270, 390), rnd.randint(80, 120)
    if ((x - 330) / 70) ** 2 + ((y - 92) / 36) ** 2 < 0.8 and ((x - 322) ** 2 + (y - 92) ** 2) > 180:
        tri(x, y, 6, 8, (70, 110, 96), (248, 248, 250))

# The rising sun, top right.
for y in range(0, 40):
    for x in range(420, 480):
        d = math.hypot(x - 452, y - 16)
        if d < 13:
            px[x, y] = ((255, 206, 110) if d < 10 else INK) + (255,)
for i in range(12):
    a = i * math.pi / 6
    for r in range(16, 22):
        x, y = int(452 + math.cos(a) * r), int(16 + math.sin(a) * r)
        if 0 <= x < W and 0 <= y < H and (r % 2 == 0):
            px[x, y] = (232, 150, 80, 255)

# Lighthouse on the coast.
lx, ly = 58, 118
for yy in range(12):
    for xx in range(-2 + yy // 6, 3 - yy // 6 + 1):
        px[lx + xx, ly - yy] = ((230, 90, 80) if (yy // 3) % 2 else (250, 246, 240)) + (255,)
px[lx, ly - 13] = (255, 220, 120, 255)

# Compass rose, bottom right.
cx, cy = 440, 232
for r in range(-12, 13):
    px[cx + r, cy] = INK_SOFT + (255,)
    px[cx, cy + r] = INK_SOFT + (255,)
for k in range(1, 6):
    for s in (-1, 1):
        px[cx + s * (6 - k) // 2, cy - 6 - k] = INK + (255,)
px[cx - 1, cy - 16] = INK + (255,)
px[cx + 1, cy - 16] = INK + (255,)
px[cx, cy - 17] = INK + (255,)

img.save(OUT)
print("wrote", OUT)
