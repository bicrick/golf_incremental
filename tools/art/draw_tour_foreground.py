"""v8 foreground framing: what's right next to a tiny rat.

One 480x270 transparent layer per range, drawn over the 3D world: giant
trunks rising out of frame, grass blades and flowers taller than the rat,
leaves hanging over the top. The middle stays clear for the range.
Light comes from the sun side of each range's sky.

Run: python3 tools/art/draw_tour_foreground.py [range ...]
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites", "tour", "foreground")
os.makedirs(OUT, exist_ok=True)
W, H = 480, 270
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hx(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def bayer(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


class Layer:
    def __init__(self):
        self.im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.px = self.im.load()

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def outline(self, c, only_below=None):
        add = []
        for y in range(H):
            for x in range(W):
                if self.px[x, y][3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = self.get(x + dx, y + dy)
                    if n[3] > 200:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[x, y] = c

    def save(self, name):
        self.im.save(os.path.join(OUT, name))


def noise(seed):
    r = random.Random(seed)
    v = [r.random() for _ in range(1024)]

    def f(x):
        i = int(math.floor(x))
        t = x - i
        t = t * t * (3 - 2 * t)
        return v[i % 1024] * (1 - t) + v[(i + 1) % 1024] * t
    return f


def ramp_pick(ramp, k, x, y):
    """k in 0..1 (0 = lit) → a ramp colour, dithered at band edges."""
    n = len(ramp)
    q = k * (n - 1)
    lo = int(q)
    frac = q - lo
    if lo >= n - 1:
        return ramp[-1]
    return ramp[lo + 1] if frac > bayer(x, y) else ramp[lo]


# --- pieces --------------------------------------------------------------------------

def trunk(L, cx, width, top, bottom, ramp, light=1, seed=1, lean=0.0, flare=1.6, bark=None):
    """A huge trunk. light=1 lit from the right, -1 from the left."""
    n = noise(seed)
    n2 = noise(seed + 5)
    for y in range(top, bottom):
        t = (y - top) / max(bottom - top, 1)
        w = width * (1 + (flare - 1) * max(0.0, t - 0.75) ** 2 * 16)
        x0 = cx + lean * (bottom - y) - w / 2 + (n(y * 0.05) - 0.5) * 4
        for x in range(int(x0), int(x0 + w) + 1):
            u = (x - x0) / max(w, 1)  # 0 left .. 1 right
            k = (1 - u) if light > 0 else u
            k = 0.15 + k * 0.8
            streak = n2(x * 0.7 + seed) + (n(y * 0.3 + x) - 0.5) * 0.3
            if streak > 0.72:
                k += 0.18
            k = max(0.0, min(1.0, k))
            c = ramp_pick(ramp, k, x, y)
            if bark and (x * 3 + int(y * 0.25)) % 11 == 0 and 0.2 < u < 0.8:
                c = bark
            L.set(x, y, c)


def canopy(L, blobs, ramp, light=1, seed=2, speck=None):
    """Leaf mass from overlapping blobs, each lit on the sun side."""
    r = random.Random(seed)
    xs = [b[0] for b in blobs]
    ys = [b[1] for b in blobs]
    rr = max(b[2] for b in blobs)
    for y in range(int(min(ys) - rr) - 2, int(max(ys) + rr) + 3):
        for x in range(int(min(xs) - rr) - 2, int(max(xs) + rr) + 3):
            best = None
            for (bx, by, br) in blobs:
                dx, dy = x + 0.5 - bx, y + 0.5 - by
                wob = 1 + 0.12 * math.sin(math.atan2(dy, dx) * 7 + bx)
                d = math.hypot(dx, dy) / (br * wob)
                if d <= 1.0:
                    k = 0.5 + (dy / br) * 0.45 - (dx / br) * 0.35 * light + d * 0.2
                    best = k if best is None else min(best, k)
            if best is None:
                continue
            c = ramp_pick(ramp, max(0.0, min(1.0, best)), x, y)
            if speck and r.random() < 0.012:
                c = speck
            L.set(x, y, c)


def blade(L, x0, y0, height, curve, width, ramp, light=1):
    """A grass blade from (x0, y0) up; curve bends the tip sideways."""
    for i in range(height):
        t = i / height
        x = x0 + curve * t * t * height * 0.5
        y = y0 - i
        w = max(1.0, width * (1 - t) ** 0.7)
        for k in range(int(-w / 2), int(w / 2) + 1):
            u = (k + w / 2) / max(w, 1)
            kk = (1 - u if light > 0 else u) * 0.7 + t * -0.15 + 0.2
            L.set(int(x + k), int(y), ramp_pick(ramp, max(0.0, min(1.0, kk)), int(x + k), int(y)))


def flower(L, x, y, stem_h, petal, center, petals=8, size=5, stem=None):
    stem = stem or hx("4f8a3a")
    for i in range(stem_h):
        L.set(x + int(math.sin(i * 0.08) * 2), y - i, stem)
        L.set(x + 1 + int(math.sin(i * 0.08) * 2), y - i, lerp(stem, hx("22301e"), 0.3))
    cx, cy = x + int(math.sin(stem_h * 0.08) * 2), y - stem_h
    for p in range(petals):
        a = p * math.tau / petals
        for rr in range(2, size + 1):
            px, py = cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.8
            L.set(int(px), int(py), petal if rr < size else lerp(petal, hx("d8c8c0"), 0.4))
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            L.set(cx + dx, cy + dy, center)


def dandelion(L, x, y, stem_h, r):
    for i in range(stem_h):
        L.set(x + int(math.sin(i * 0.05) * 3), y - i, hx("6a9a4a"))
    cx, cy = x + int(math.sin(stem_h * 0.05) * 3), y - stem_h
    rnd = random.Random(x)
    for i in range(160):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0.2, 1.0) * r
        px, py = cx + math.cos(a) * d, cy + math.sin(a) * d
        L.set(int(px), int(py), hx("ffffff", 230) if d > r * 0.5 else hx("e8ece8", 200))
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            L.set(cx + dx, cy + dy, hx("c8b890"))


def rock(L, cx, base, w, h, ramp, light=1, seed=3):
    n = noise(seed)
    for x in range(int(cx - w / 2), int(cx + w / 2)):
        u = (x - (cx - w / 2)) / w
        top = base - h * (math.sin(u * math.pi) ** 0.6) * (0.85 + 0.15 * n(x * 0.2))
        for y in range(int(top), base):
            v = (y - top) / max(base - top, 1)
            k = (1 - u if light > 0 else u) * 0.55 + v * 0.45
            L.set(x, y, ramp_pick(ramp, max(0.0, min(1.0, k)), x, y))


def column(L, cx, width, top, bottom, ramp, light=1, ribs=0, rib_c=None, spine=None, round_top=True):
    """A rounded vertical column (cactus arm, pillar): cylinder shading, optional ribs."""
    for y in range(top, bottom):
        if round_top and y - top < width / 2:
            dy = (width / 2 - (y - top)) / (width / 2)
            half = width / 2 * math.sqrt(max(0.0, 1 - dy * dy))
        else:
            half = width / 2
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x - cx) / max(width / 2, 1)
            k = 0.5 - u * 0.45 * light
            k = max(0.0, min(1.0, k + (abs(u) ** 3) * 0.35))
            c = ramp_pick(ramp, k, x, y)
            if ribs and rib_c and int((u + 1) * ribs) % 2 == 1 and abs(u) < 0.92:
                c = lerp(c, rib_c, 0.45)
                if spine and (y + x) % 7 == 0:
                    c = spine
            L.set(x, y, c)


def elbow(L, x0, y0, x1, width, ramp, light=1):
    """Horizontal arm from x0 to x1 at y0, thickness width."""
    for x in range(min(x0, x1), max(x0, x1) + 1):
        for y in range(int(y0 - width / 2), int(y0 + width / 2) + 1):
            v = (y - y0) / max(width / 2, 1)
            k = max(0.0, min(1.0, 0.45 + v * 0.45))
            L.set(x, y, ramp_pick(ramp, k, x, y))


def ledge_rock(L, x0, x1, y_top, y_bottom, ramp, light=1, seed=5, cap=None):
    """A cliff chunk made of stacked, uneven ledges."""
    r = random.Random(seed)
    y = y_top
    edge_l, edge_r = x0, x1
    while y < y_bottom:
        seg = r.randint(8, 18)
        edge_l = x0 + r.randint(-6, 8)
        edge_r = x1 + r.randint(-10, 6)
        for yy in range(y, min(y + seg, y_bottom)):
            t = (yy - y) / seg
            for x in range(edge_l, edge_r):
                u = (x - edge_l) / max(edge_r - edge_l, 1)
                k = (1 - u if light > 0 else u) * 0.5 + t * 0.35 + 0.05
                if t > 0.85:
                    k += 0.3
                c = ramp_pick(ramp, max(0.0, min(1.0, k)), x, yy)
                if r.random() < 0.01:
                    c = ramp[-1]
                L.set(x, yy, c)
            if cap and t < 0.15 and yy == y:
                for x in range(edge_l - 2, edge_r + 2):
                    L.set(x, yy - 1, cap[0])
                    L.set(x, yy, cap[1])
        y += seg


def light_shafts(L, x0, x1, color, count=5, seed=4):
    r = random.Random(seed)
    for i in range(count):
        sx = r.randint(x0, x1)
        width = r.randint(6, 14)
        for y in range(0, 200):
            xs = sx + y * 0.35
            a = int(34 * (1 - y / 200))
            for k in range(width):
                if (int(xs) + k + y) % 3 == 0 and L.get(int(xs) + k, y)[3] == 0:
                    L.set(int(xs) + k, y, color[:3] + (a,))


# ======================================================================================

def barley():
    L = Layer()
    bark = [hx("8a6a52"), hx("6e523e"), hx("54402f"), hx("3a2a22")]
    leaf = [hx("9fd06a"), hx("6fae4e"), hx("4a8a3e"), hx("2f5f34")]
    pine = [hx("5f9a6a"), hx("3f7a56"), hx("2c5a44"), hx("1c3a30")]
    # A great oak on the left: trunk off the top, canopy hanging over.
    trunk(L, 26, 44, 0, 214, bark, light=-1, seed=1, lean=-0.03, flare=1.9, bark=hx("3a2a22"))
    canopy(L, [(40, -6, 60), (100, 4, 44), (150, -10, 40), (-10, 40, 40), (60, 30, 34)], leaf, light=-1, seed=2,
           speck=hx("ffe9a0"))
    # A giant pine on the right edge.
    trunk(L, 462, 30, 0, 206, bark, light=-1, seed=7, flare=1.7, bark=hx("3a2a22"))
    for i in range(6):
        y = 10 + i * 22
        w = 40 + i * 9
        canopy(L, [(470 - w * 0.3, y, w * 0.45), (480, y + 6, w * 0.5)], pine, light=-1, seed=10 + i)
    # Foreground grass and flowers: taller than the rat.
    r = random.Random(12)
    grass = [hx("b4e07a"), hx("7fbf56"), hx("4f9440"), hx("2f6a34")]
    for i in range(46):
        x = r.choice([r.randint(-5, 120), r.randint(330, 485)])
        blade(L, x, 272, r.randint(24, 80), r.uniform(-1.2, 1.2), r.uniform(3, 6), grass, light=-1)
    dandelion(L, 108, 270, 96, 15)
    flower(L, 356, 270, 70, hx("ffffff"), hx("f2c440"), petals=10, size=7)
    flower(L, 392, 270, 50, hx("ffd0e0"), hx("f2c440"), petals=8, size=5)
    flower(L, 70, 270, 58, hx("fff4a0"), hx("e0a030"), petals=9, size=5)
    L.outline(hx("1c2418", 255))
    light_shafts(L, 120, 300, hx("fff0c8"), count=6)
    L.save("barley.png")


def cliffs():
    L = Layer()
    rockr = [hx("f4ecd8"), hx("dccca8"), hx("b8a484"), hx("8a7864"), hx("5e5048")]
    grass = [hx("e2e39a"), hx("b8c268"), hx("849a48"), hx("4e6a30")]
    capc = (hx("b8d070"), hx("7a9a48"))
    # A chalk headland rising out of frame on the left, in stacked ledges.
    ledge_rock(L, -10, 70, 0, 272, rockr, light=1, seed=3, cap=capc)
    ledge_rock(L, -10, 118, 150, 272, rockr, light=1, seed=4, cap=capc)
    r = random.Random(21)
    for i in range(36):
        x = r.randint(0, 120)
        top = 150 + r.randint(-4, 4) if x > 60 else r.randint(0, 150)
        blade(L, x, top + 2, r.randint(6, 18), r.uniform(-1, 1), 2, grass, light=1)
    # Dune grass and sea thrift towering at the bottom right.
    for i in range(44):
        x = r.randint(320, 485)
        blade(L, x, 272, r.randint(30, 100), r.uniform(-1.8, 0.3), r.uniform(2.5, 5), grass, light=1)
    for x, h in [(352, 70), (396, 88), (436, 60), (128, 42), (150, 30)]:
        flower(L, x, 270, h, hx("f08ab8"), hx("c04a80"), petals=12, size=6, stem=hx("7a9a4a"))
    L.outline(hx("2a2428"))
    L.save("cliffs.png")


def mesa():
    L = Layer()
    cact = [hx("b0dc88"), hx("7ab464"), hx("548a4e"), hx("365e3c"), hx("223a2a")]
    red = [hx("f8b080"), hx("e07a4c"), hx("b85a38"), hx("843c2a"), hx("542420")]
    # A giant saguaro on the left, ribbed and spiny, lit by the low sun (right).
    column(L, 44, 54, -10, 272, cact, light=-1, ribs=6, rib_c=cact[3], spine=hx("f8f0d0"))
    elbow(L, 70, 150, 104, 26, cact)
    column(L, 104, 28, 70, 164, cact, light=-1, ribs=4, rib_c=cact[3], spine=hx("f8f0d0"))
    column(L, 104, 16, 60, 78, [hx("f8d060"), hx("f0a040"), hx("c87030")], light=-1, round_top=True)
    # A banded red pillar on the right.
    ledge_rock(L, 400, 490, -10, 272, red, light=-1, seed=33)
    r = random.Random(34)
    scrub = [hx("d8cc90"), hx("b0a468"), hx("807848"), hx("50482e")]
    for i in range(30):
        x = r.choice([r.randint(70, 160), r.randint(320, 410)])
        blade(L, x, 272, r.randint(14, 44), r.uniform(-1, 1), 3, scrub, light=1)
    flower(L, 146, 270, 36, hx("f8d040"), hx("e07a30"), petals=7, size=5, stem=hx("7a8a4a"))
    flower(L, 344, 270, 30, hx("f07aa8"), hx("fff0a0"), petals=6, size=4, stem=hx("7a8a4a"))
    L.outline(hx("2a1a1e"))
    L.save("mesa.png")


def frost():
    L = Layer()
    bark = [hx("4a4660"), hx("363248"), hx("262236"), hx("16142a")]
    fir = [hx("3a6a78"), hx("284e5e"), hx("1a3646"), hx("0e1e2c")]
    snow = [hx("ffffff"), hx("dce6f8"), hx("aebcdc"), hx("7a88b0")]
    trunk(L, 30, 40, 0, 272, bark, light=1, seed=41, flare=1.4)
    trunk(L, 452, 46, 0, 272, bark, light=-1, seed=42, flare=1.4)
    for side, cx in [(-1, 30), (1, 452)]:
        for i in range(7):
            y = -10 + i * 30
            w = 70 + i * 6
            canopy(L, [(cx + side * -w * 0.25, y, w * 0.4)], fir, light=-side, seed=50 + i + cx)
            canopy(L, [(cx + side * -w * 0.3, y - 12, w * 0.28)], snow, light=-side, seed=60 + i + cx)
    # Snowbanks at the bottom.
    for x in range(W):
        for y in range(230, H):
            d = 272 - 26 * (math.sin(x * 0.02) * 0.5 + 0.5) * (1 if x < 150 or x > 330 else 0.2)
            if y > d:
                L.set(x, y, ramp_pick(snow, min(1.0, (y - d) / 30 + 0.1), x, y))
    L.outline(hx("0c1020"))
    L.save("frost.png")


def edge():
    L = Layer()
    stone = [hx("f2d8e4"), hx("d0b0c8"), hx("a88aac"), hx("7a6488"), hx("4e3a5e")]
    cloud = [hx("fff8f8", 245), hx("f8dce8", 240), hx("e8c0d8", 235), hx("c8a0c8", 235)]
    # Two ancient stone pillars rising out of the cloud sea, carved and weathered.
    column(L, 36, 64, -10, 272, stone, light=1, ribs=5, rib_c=stone[3], round_top=False)
    column(L, 446, 70, -10, 272, stone, light=-1, ribs=5, rib_c=stone[3], round_top=False)
    for y in range(20, 272, 38):
        for x in list(range(4, 70)) + list(range(410, 482)):
            if L.get(x, y)[3]:
                L.set(x, y, stone[4])
                L.set(x, y + 1, stone[1])
    # Ivy trailing down the left pillar, lit gold at the edges.
    r = random.Random(74)
    ivy = [hx("c8e08a"), hx("8ab86a"), hx("5a8a58"), hx("345a44")]
    for vine in range(4):
        x = 20 + vine * 12
        for y in range(0, r.randint(80, 200), 2):
            x += r.choice([-1, 0, 1])
            L.set(x, y, ivy[2])
            if y % 6 == 0:
                canopy(L, [(x + r.choice([-3, 3]), y, 3)], ivy, light=1, seed=y + x)
    moss = [hx("a8c890"), hx("7aa070"), hx("50785a"), hx("2e4a3e")]
    for i in range(24):
        x = r.choice([r.randint(60, 130), r.randint(350, 420)])
        blade(L, x, 272, r.randint(10, 34), r.uniform(-1, 1), 3, moss, light=1)
    flower(L, 132, 270, 46, hx("fbfbf2"), hx("e8d890"), petals=6, size=6, stem=hx("8aa080"))
    for (cx, cy, rr) in [(30, 250, 44), (92, 264, 30), (446, 246, 48), (386, 264, 30)]:
        canopy(L, [(cx, cy, rr), (cx + rr * 0.7, cy + 4, rr * 0.7)], cloud, light=1, seed=cx)
    L.outline(hx("3a2a44"))
    L.save("edge.png")


if __name__ == "__main__":
    for name in sys.argv[1:] or ["barley", "cliffs", "mesa", "frost", "edge"]:
        globals()[name]()
        print("drew", name)
