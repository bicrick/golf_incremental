"""v8 backdrops: five ranges, painted at the game's native 480 px width.

Each range gets parallax layers (sky, far, clouds, mid, near). The horizon
is row 96 (TourWorld.HORIZON_Y); land layers run a few rows past it so the 3D
ground always meets painted land. Clouds are 960 wide and wrap.

Run: python3 tools/art/draw_tour_backdrops.py [range_id ...]
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites", "tour", "backdrops")
os.makedirs(OUT, exist_ok=True)
W, H = 480, 104
HZ = 96  # horizon row
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hx(h: str, a: int = 255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def bayer(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


class Layer:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def set(self, x, y, c):
        if 0 <= y < self.h:
            x %= self.w
            if len(c) == 4 and c[3] < 255:
                base = self.px[x, y]
                if base[3] == 0:
                    self.px[x, y] = c
                else:
                    a = c[3] / 255.0
                    self.px[x, y] = tuple(int(base[i] * (1 - a) + c[i] * a) for i in range(3)) + (max(base[3], c[3]),)
            else:
                self.px[x, y] = c if len(c) == 4 else c + (255,)

    def get(self, x, y):
        if 0 <= y < self.h:
            return self.px[x % self.w, y]
        return (0, 0, 0, 0)

    def save(self, name):
        self.im.save(os.path.join(OUT, name))


# --- noise ------------------------------------------------------------------------

class Noise1D:
    def __init__(self, seed, period=None):
        r = random.Random(seed)
        self.v = [r.random() for _ in range(4096)]
        self.period = period

    def at(self, x):
        if self.period:
            x = x % self.period
        i = int(math.floor(x))
        f = x - i
        f = f * f * (3 - 2 * f)
        n = len(self.v)
        if self.period:
            a, b = self.v[i % self.period], self.v[(i + 1) % self.period]
        else:
            a, b = self.v[i % n], self.v[(i + 1) % n]
        return a + (b - a) * f

    def fbm(self, x, octaves=5, lac=2.0, gain=0.5):
        amp, freq, s, norm = 1.0, 1.0, 0.0, 0.0
        for o in range(octaves):
            p = (self.period * (2 ** o)) if self.period else None
            if p:
                xx = (x * freq) % p
                i = int(math.floor(xx)); f = xx - i; f = f * f * (3 - 2 * f)
                a, b = self.v[(i + o * 97) % p % len(self.v)], self.v[((i + 1) % p + o * 97) % len(self.v)]
                s += amp * (a + (b - a) * f)
            else:
                s += amp * self.at(x * freq + o * 31.7)
            norm += amp
            amp *= gain
            freq *= lac
        return s / norm


def ridge_line(seed, base, amp, scale, octaves=5, sharp=0.0, w=W):
    n = Noise1D(seed)
    out = []
    for x in range(w):
        v = n.fbm(x / scale, octaves)
        if sharp:
            v = (1 - abs(v * 2 - 1)) * sharp + v * (1 - sharp)
        out.append(base - v * amp)
    return out


# --- painting helpers -------------------------------------------------------------------

def sky_gradient(L, stops, y0=0, y1=HZ + 8):
    """stops: list of (t, color); dithered 2-colour bands, pixel-art style."""
    for y in range(y0, min(y1, L.h)):
        t = (y - y0) / max(y1 - y0 - 1, 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                a, b = stops[i], stops[i + 1]
                u = (t - a[0]) / max(b[0] - a[0], 1e-6)
                break
        steps = 6
        q = u * steps
        lo = int(q)
        frac = q - lo
        c_lo = lerp(a[1], b[1], lo / steps)
        c_hi = lerp(a[1], b[1], min(lo + 1, steps) / steps)
        for x in range(L.w):
            L.set(x, y, c_hi if frac > bayer(x, y) else c_lo)


def fill_below(L, line, ramp, light_dir=1.0, snow=None, snow_line=None, texture=0.0, seed=1, y_end=H,
               rim=None, shade_amt=1.0, snow_depth=10):
    """Fill under a height line. ramp = [lit, mid, shadow]; smoothed slope decides light."""
    n = Noise1D(seed + 7)
    n2 = Noise1D(seed + 13)
    w = len(line)
    for x in range(w):
        top = int(round(line[x]))
        slope = (line[(x + 3) % w] - line[x - 3]) / 6.0
        lit = slope * light_dir  # >0: facing the light
        sd = snow_depth * (0.5 + n2.fbm(x / 14.0, 3))
        for y in range(max(top, 0), y_end):
            depth = y - top
            k = 0.5 - lit * 0.9 * shade_amt + depth * 0.01
            k += (n.fbm(x * 0.08 + y * 0.21, 3) - 0.5) * texture
            if k < 0.36 + (bayer(x, y) - 0.5) * 0.1:
                c = ramp[0]
            elif k < 0.64 + (bayer(x, y) - 0.5) * 0.1:
                c = ramp[1]
            else:
                c = ramp[2]
            if snow and snow_line is not None and y < snow_line and depth < sd:
                c = snow[0] if lit > -0.15 else snow[1]
            L.set(x, y, c)
        if rim and top >= 0 and lit > 0.15:
            L.set(x, top, rim)


def disc(L, cx, cy, r, c, glow=None, glow_r=0):
    for y in range(int(cy - r - glow_r) - 1, int(cy + r + glow_r) + 2):
        for x in range(int(cx - r - glow_r) - 1, int(cx + r + glow_r) + 2):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                L.set(x, y, c)
            elif glow and d <= r + glow_r:
                t = (d - r) / glow_r
                if (1 - t) ** 1.5 > bayer(x, y) * 1.1:
                    L.set(x, y, glow)


def cloud(L, cx, cy, width, height, lit, mid, shade, seed, flat=True, alpha=255):
    r = random.Random(seed)
    puffs = []
    n = max(3, int(width / (height * 0.9)))
    for i in range(n):
        t = (i + 0.5) / n
        px = cx - width / 2 + t * width + r.uniform(-3, 3)
        rr = height * (0.55 + 0.45 * math.sin(t * math.pi)) * r.uniform(0.8, 1.1)
        puffs.append((px, cy - rr * 0.35, rr))
    bottom = cy + height * 0.28
    minx = int(cx - width / 2 - height)
    maxx = int(cx + width / 2 + height)
    for y in range(int(cy - height * 1.4), int(bottom) + 1):
        for x in range(minx, maxx + 1):
            inside = None
            for (px, py, rr) in puffs:
                d = math.hypot(x + 0.5 - px, (y + 0.5 - py) * 1.15)
                if d <= rr:
                    # lighting: normal toward top-left/top
                    ny = (y + 0.5 - py) / rr
                    nx = (x + 0.5 - px) / rr
                    inside = max(inside or -9, -ny * 0.8 - nx * 0.25)
            if inside is None:
                continue
            if flat and y > bottom - 1:
                continue
            if inside > 0.35:
                c = lit
            elif inside > -0.15 + (bayer(x, y) - 0.5) * 0.3:
                c = mid
            else:
                c = shade
            c = c[:3] + (alpha,)
            L.set(x, y, c)


def pine(L, x, base, h, dark, mid, rim=None, snow=None, light_dir=1):
    w = max(2, int(h * 0.42))
    for yy in range(h):
        t = yy / h
        # layered tiers
        tier = (yy % max(3, h // 4)) / max(3, h // 4)
        half = int((t * 0.9 + 0.1) * w * (0.75 + 0.25 * tier))
        for xx in range(-half, half + 1):
            c = dark
            if xx * light_dir > half * 0.25:
                c = mid
            if snow and tier < 0.3 and abs(xx) < half:
                c = snow
            L.set(x + xx, base - h + yy, c)
        if rim and half > 0:
            L.set(x + half * light_dir, base - h + yy, rim)
    L.set(x, base - h - 1, dark)
    for yy in range(0, 3):
        L.set(x, base + yy - 1, dark)


def blob_tree(L, x, base, h, dark, mid, lit, seed):
    r = random.Random(seed)
    rad = h * 0.45
    cy = base - h + rad
    for (ox, oy, rr) in [(0, 0, rad), (-rad * 0.6, rad * 0.25, rad * 0.7), (rad * 0.6, rad * 0.3, rad * 0.7)]:
        for yy in range(int(cy + oy - rr) - 1, int(cy + oy + rr) + 2):
            for xx in range(int(x + ox - rr) - 1, int(x + ox + rr) + 2):
                d = math.hypot(xx + 0.5 - x - ox, yy + 0.5 - cy - oy)
                if d <= rr:
                    ny = (yy + 0.5 - cy - oy) / rr
                    nx = (xx + 0.5 - x - ox) / rr
                    k = -ny * 0.7 - nx * 0.4
                    c = lit if k > 0.45 else (mid if k > -0.1 + (bayer(xx, yy) - 0.5) * 0.3 else dark)
                    L.set(xx, yy, c)
    for yy in range(int(cy + rad * 0.6), base + 1):
        L.set(x, yy, dark)


def stars(L, count, seed, y_max, colors, twinkle_cross=6):
    r = random.Random(seed)
    for i in range(count):
        x, y = r.randrange(L.w), r.randrange(0, y_max)
        fade = 1 - y / y_max
        if r.random() > fade * 1.2:
            continue
        c = r.choice(colors)
        L.set(x, y, c)
        if i < twinkle_cross:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                L.set(x + dx, y + dy, c[:3] + (140,))


def haze_band(L, y0, y1, color, max_a=200):
    """Soft mist sitting on the horizon (dithered alpha)."""
    for y in range(y0, y1):
        t = (y - y0) / max(y1 - y0 - 1, 1)
        a = t ** 1.3
        for x in range(L.w):
            if a > bayer(x, y) * 0.95:
                L.set(x, y, color[:3] + (max_a,))


# ============================================================================
# I. Barley's Range — dawn meadow
# ============================================================================

def barley():
    sky = Layer()
    sky_gradient(sky, [(0.0, hx("3b3a6e")), (0.35, hx("8a5f95")), (0.62, hx("e48f8f")),
                       (0.82, hx("f6b98e")), (1.0, hx("fbe0b0"))])
    # Sun just clearing the saddle, left of centre.
    disc(sky, 150, 74, 8, hx("fff3c4"), hx("ffd99a"), 18)
    for i in range(10):  # long dawn rays
        a = math.pi + 0.25 + i * 0.28
        for r in range(26, 26 + 18 + (i % 3) * 8):
            x, y = int(150 + math.cos(a) * r), int(74 + math.sin(a) * r * 0.8)
            if (r + i) % 3:
                sky.set(x, y, hx("ffe9b8", 70))
    stars(sky, 60, 3, 34, [hx("e8e4ff"), hx("c9c4f0")], 3)
    sky.save("barley_sky.png")

    far = Layer()
    line = ridge_line(11, 84, 30, 46, 5, sharp=0.6)
    for x in range(W):
        line[x] -= 16 * math.exp(-((x - 330) / 50) ** 2) + 10 * math.exp(-((x - 40) / 40) ** 2)
        line[x] += 16 * math.exp(-((x - 150) / 30) ** 2)  # saddle for the sun
    fill_below(far, line, [hx("c7a8c4"), hx("a88fb2"), hx("8c7aa0")], light_dir=-1,
               snow=(hx("ffe8e0"), hx("dcc6da")), snow_line=70, snow_depth=9, texture=0.35, seed=11, rim=hx("ffe6d6"))
    line2 = ridge_line(12, 92, 12, 34, 4, sharp=0.3)
    fill_below(far, line2, [hx("8f8fb0"), hx("7a7ca0"), hx("696b92")], light_dir=-1, texture=0.25, seed=12)
    haze_band(far, 82, 98, hx("f3cfb3"), 150)
    far.save("barley_far.png")

    clouds = Layer(960)
    r = random.Random(5)
    for i in range(9):
        cx = i * 107 + r.randint(0, 50)
        cy = r.randint(16, 46)
        cloud(clouds, cx, cy, r.randint(40, 90), r.randint(6, 11),
              hx("ffe2d0"), hx("f2b3a8"), hx("c98f9e"), 100 + i, alpha=235)
    clouds.save("barley_clouds.png")

    mid = Layer()
    line = ridge_line(21, 97, 9, 60, 3)
    fill_below(mid, line, [hx("8aa27e"), hx("75906e"), hx("627d62")], light_dir=-1, texture=0.3, seed=21)
    haze_band(mid, 88, 100, hx("f0c9b0"), 140)
    mid.save("barley_mid.png")

    near = Layer()
    r = random.Random(31)
    trees = []
    for x in range(-6, W + 6, 5):
        edge = min(x, W - x)
        if 140 < x < 340:
            if r.random() < 0.85:
                continue
            h = r.randint(5, 8)
        else:
            h = r.randint(9, 16) + max(0, 70 - edge) // 5
        trees.append((x + r.randint(-2, 2), h, r.random() < 0.4))
    for x, h, round_ in sorted(trees, key=lambda t: t[1]):
        if round_:
            blob_tree(near, x, 99, h, hx("2f4a3a"), hx("3f5f45"), hx("6f8a55"), x)
        else:
            pine(near, x, 99, h, hx("26403a"), hx("34574a"), light_dir=-1)
    # The white barn, left of the fairway.
    bx, by = 104, 98
    for y in range(by - 12, by):
        for x in range(bx - 10, bx + 11):
            near.set(x, y, hx("f0e8dc") if x < bx + 4 else hx("c8bcb0"))
    for i in range(11):
        for x in range(bx - 12 + i, bx + 13 - i):
            near.set(x, by - 12 - i // 2 - 1, hx("b04a40") if x < bx + 3 else hx("7c3530"))
    for y in range(by - 7, by):
        for x in range(bx - 3, bx + 3):
            near.set(x, y, hx("7c3530"))
    for x in range(bx - 3, bx + 3):
        near.set(x, by - 4 - abs(x - bx + 0.5) // 2, hx("f0e8dc"))
    near.set(bx - 7, by - 9, hx("f6d27a"))
    near.set(bx - 6, by - 9, hx("f6d27a"))
    haze_band(near, 93, 100, hx("fbe9e0"), 140)
    near.save("barley_near.png")


# ============================================================================
# II. Saltwind Cliffs — late morning by the sea
# ============================================================================

def cliffs():
    sky = Layer()
    sky_gradient(sky, [(0.0, hx("3d7fc4")), (0.5, hx("6fb2e0")), (0.85, hx("a8d8ef")), (1.0, hx("dff2f7"))])
    disc(sky, 400, 16, 7, hx("fffbe8"), hx("fff1c0"), 10)
    sky.save("cliffs_sky.png")

    far = Layer()
    # The sea: from the horizon at row 78 down to the land.
    sea_top = 78
    for y in range(sea_top, H):
        t = (y - sea_top) / (H - sea_top)
        for x in range(W):
            c = lerp(hx("5c9ecb"), hx("2f77a8"), t)
            if (x * 7 + y * 13) % 29 == 0 and random.Random(x * 31 + y).random() < 0.5:
                c = hx("e8f7ff")
            far.set(x, y, c)
    for x in range(W):
        far.set(x, sea_top, hx("b7dff2"))
    # Distant islands.
    for cx, w_, h_ in [(70, 50, 6), (380, 36, 4)]:
        for x in range(cx - w_ // 2, cx + w_ // 2):
            t = (x - cx) / (w_ / 2)
            hh = int(h_ * (1 - t * t))
            for y in range(sea_top - hh, sea_top + 1):
                far.set(x, y, hx("7aa3b8"))
    far.save("cliffs_far.png")

    clouds = Layer(960)
    r = random.Random(9)
    for i in range(7):
        cx = i * 140 + r.randint(0, 60)
        cy = r.randint(26, 58)
        cloud(clouds, cx, cy, r.randint(60, 120), r.randint(12, 20), hx("ffffff"), hx("e3eef6"), hx("b8cde0"), 200 + i)
    clouds.save("cliffs_clouds.png")

    mid = Layer()
    # A grassy headland on the right with the lighthouse; sea stacks on the left.
    n = Noise1D(41)
    top_line = [999.0] * W
    for x in range(W):
        if x >= 318:
            t = (x - 318) / 162.0
            top_line[x] = 64 - 14 * min(t * 3, 1) + (n.fbm(x / 16.0, 3) - 0.5) * 6
    for x in range(318, W):
        top = int(top_line[x])
        face = x < 330  # the seaward face, in shadow
        for y in range(top, H):
            depth = y - top
            crack = (n.at(x * 0.9) > 0.8) and depth > 4
            band = ((y + int(n.at(x * 0.15) * 5)) // 5) % 2
            c = hx("d8c4a0") if band else hx("c4ae8c")
            if face or x < 322 + (y - top) // 6:
                c = hx("9a8672") if band else hx("8a7662")
            if crack:
                c = hx("7a6652")
            if (x + y * 3) % 23 == 0:
                c = hx("f0e2c4")
            if depth < 3:
                c = hx("7fb055") if depth < 2 else hx("5f8f40")
            mid.set(x, y, c)
        # grass overhang
        if (x * 7) % 5 == 0:
            mid.set(x, top - 1, hx("9ccb68"))
    # Foam at the cliff foot.
    for x in range(300, 340):
        for y in range(88, 97):
            if (x * 3 + y * 5) % 7 == 0 and y > 90 - (x - 300) // 10:
                mid.set(x, y, hx("f4fbff"))
    # Sea stacks.
    for cx, h_, w_ in [(58, 26, 9), (80, 14, 6)]:
        for y in range(96 - h_, 97):
            k = (y - (96 - h_)) / h_
            half = int(w_ * (0.6 + 0.4 * k) / 2)
            for x in range(cx - half, cx + half + 1):
                c = hx("c4ae8c") if x < cx else hx("8a7662")
                if y < 96 - h_ + 2:
                    c = hx("7fb055")
                mid.set(x, y, c)
        for x in range(cx - w_, cx + w_):
            if x % 2:
                mid.set(x, 95, hx("f4fbff"))
    # Lighthouse.
    lx = 436
    ly = int(top_line[lx]) + 1
    for y in range(ly - 34, ly):
        k = (ly - y) / 34
        half = int(5 - k * 2)
        band = ((ly - y) // 6) % 2
        for x in range(lx - half, lx + half + 1):
            c = hx("e24b3f") if band else hx("f7f2ea")
            if x > lx + half // 2:
                c = hx("b8352c") if band else hx("d9d2c8")
            mid.set(x, y, c)
    for x in range(lx - 4, lx + 5):
        mid.set(x, ly - 35, hx("2d2433"))
    for y in range(ly - 41, ly - 35):
        for x in range(lx - 3, lx + 4):
            mid.set(x, y, hx("ffe9a0") if abs(x - lx) < 2 else hx("2d2433"))
    for x in range(lx - 4, lx + 5):
        mid.set(x, ly - 42, hx("e24b3f"))
    for x in range(lx - 2, lx + 3):
        mid.set(x, ly - 43, hx("e24b3f"))
    # Keeper's cottage.
    for y in range(ly - 8, ly):
        for x in range(lx - 22, lx - 8):
            mid.set(x, y, hx("f7f2ea") if x < lx - 12 else hx("d9d2c8"))
    for i in range(5):
        for x in range(lx - 23 + i, lx - 7 - i):
            mid.set(x, ly - 9 - i, hx("4a6a8a"))
    mid.set(lx - 18, ly - 5, hx("ffe9a0"))
    mid.save("cliffs_mid.png")

    near = Layer()
    r = random.Random(51)
    # Dune grass tufts on the left edge and rocks.
    for x in range(0, 150, 2):
        if r.random() < 0.6:
            h = r.randint(3, 9) + max(0, 60 - x) // 8
            for k in range(h):
                near.set(x + (k // 3) * (1 if x % 4 else -1), 98 - k, hx("8a9d58") if k < h - 2 else hx("c9cf8a"))
    for x in range(360, W, 2):
        if r.random() < 0.4:
            h = r.randint(2, 6)
            for k in range(h):
                near.set(x, 98 - k, hx("6f8f48"))
    near.save("cliffs_near.png")


# ============================================================================
# III. Redrock Mesa — dusk
# ============================================================================

def mesa():
    sky = Layer()
    sky_gradient(sky, [(0.0, hx("3a2a5e")), (0.3, hx("7a3f7a")), (0.55, hx("d8607a")),
                       (0.78, hx("f59a64")), (1.0, hx("fcd28a"))])
    disc(sky, 246, 82, 15, hx("fff0b0"), hx("ffc278"), 22)
    stars(sky, 40, 9, 26, [hx("f4e4ff")], 2)
    sky.save("mesa_sky.png")

    clouds = Layer(960)
    r = random.Random(13)
    for i in range(8):
        cx = i * 120 + r.randint(0, 40)
        cy = r.randint(20, 60)
        # long thin sunset streaks
        cloud(clouds, cx, cy, r.randint(80, 150), r.randint(4, 7), hx("ffd0a0"), hx("f08a80"), hx("a9507a"), 300 + i, alpha=240)
    clouds.save("mesa_clouds.png")

    def mesa_line(seed, base, count, hmin, hmax, wmin, wmax):
        r = random.Random(seed)
        line = [base + 0.0] * W
        for _ in range(count):
            cx = r.randint(-20, W + 20)
            while 170 < cx < 320:
                cx = r.randint(-20, W + 20)
            w_ = r.randint(wmin, wmax)
            h_ = r.randint(hmin, hmax)
            for x in range(cx - w_ // 2 - 6, cx + w_ // 2 + 7):
                if 0 <= x < W:
                    d = abs(x - cx) - w_ / 2
                    top = base - h_ if d <= 0 else base - h_ + d * (h_ / 6.0)
                    line[x] = min(line[x], top)
        return line

    far = Layer()
    line = mesa_line(61, 94, 7, 14, 26, 30, 90)
    fill_below(far, line, [hx("8a4a7a"), hx("7a3f70"), hx("6a3566")], light_dir=1, seed=61, shade_amt=0.4)
    haze_band(far, 82, 98, hx("f2a071"), 150)
    far.save("mesa_far.png")

    mid = Layer()
    line = mesa_line(71, 98, 5, 20, 40, 24, 70)
    n = Noise1D(72)
    for x in range(W):
        top = int(line[x])
        for y in range(max(top, 0), H):
            depth = y - top
            band = ((y + int(n.at(x * 0.05) * 6)) // 4) % 3
            ramp = [hx("c5553a"), hx("a8452f"), hx("8e3a2c")]
            c = ramp[band]
            lit = line[(x + 1) % W] - line[x - 1]
            if lit < -0.5:  # faces the low sun (right)
                c = lerp(c, hx("f08a50"), 0.35)
            if depth == 0:
                c = hx("f7a468")
            mid.set(x, y, c)
    haze_band(mid, 90, 100, hx("f2a071"), 120)
    mid.save("mesa_mid.png")

    near = Layer()
    r = random.Random(81)

    def saguaro(x, base, h):
        col, lit = hx("3a2a3e"), hx("5a3a48")
        for y in range(base - h, base + 1):
            near.set(x, y, col)
            near.set(x + 1, y, col)
            near.set(x - 1, y, lit if y > base - h + 1 else col)
        for side, ay, al in [(-1, base - h // 2, h // 3), (1, base - h // 2 - 3, h // 3 + 2)]:
            for k in range(3):
                near.set(x + side * (2 + k), ay, col)
            for k in range(al):
                near.set(x + side * 4, ay - k, col)
                near.set(x + side * 5, ay - k, col)

    for x in list(range(10, 150, 23)) + list(range(340, 470, 29)):
        saguaro(x + r.randint(-6, 6), 99, r.randint(12, 22))
    for x in range(0, W, 3):
        if (x < 160 or x > 320) and r.random() < 0.5:
            h = r.randint(1, 4)
            for k in range(h):
                near.set(x, 99 - k, hx("5a3a48"))
    near.save("mesa_near.png")


# ============================================================================
# IV. Frostpine — night, aurora
# ============================================================================

def frost():
    sky = Layer()
    sky_gradient(sky, [(0.0, hx("070b22")), (0.5, hx("111a44")), (0.85, hx("1f2c5e")), (1.0, hx("2e3d72"))])
    stars(sky, 380, 17, 90, [hx("ffffff"), hx("d8e4ff"), hx("ffeccc"), hx("9fb4ff")], 10)
    disc(sky, 96, 22, 7, hx("f6f4e6"), hx("8a98c8"), 8)
    # moon craters
    for (cx, cy) in [(94, 20), (99, 25), (97, 18)]:
        sky.set(cx, cy, hx("d8d4c4"))
    sky.save("frost_sky.png")

    aur = Layer(960)
    n = Noise1D(91)
    for x in range(960):
        base = 30 + math.sin(x / 70.0) * 10 + math.sin(x / 23.0) * 4
        strength = max(0.0, math.sin(x / 110.0 + 1.2)) ** 1.5 * (0.6 + 0.4 * n.at(x / 9.0))
        length = int(10 + 26 * strength)
        for k in range(length):
            y = int(base) - k
            t = k / max(length, 1)
            a = int(220 * strength * (1 - t) ** 1.2)
            if a < 10 or bayer(x, y) * 255 > a * 1.6:
                continue
            c = lerp(hx("5cf2b0"), hx("8a6cf0"), t)
            aur.set(x, y, c[:3] + (min(a, 200),))
    aur.save("frost_clouds.png")

    far = Layer()
    line = ridge_line(101, 90, 44, 60, 5, sharp=0.7)
    for x in range(W):
        line[x] -= 12 * math.exp(-((x - 360) / 70) ** 2)
    fill_below(far, line, [hx("c9d4ee"), hx("8e9cc4"), hx("5d6a98")], light_dir=1,
               snow=(hx("eef3ff"), hx("aab6d8")), snow_line=74, texture=0.25, seed=101)
    haze_band(far, 84, 98, hx("24305a"), 170)
    far.save("frost_far.png")

    mid = Layer()
    r = random.Random(111)
    for x in range(-4, W + 4, 4):
        if 170 < x < 310 and r.random() < 0.75:
            continue
        h = r.randint(10, 18)
        pine(mid, x + r.randint(-1, 1), 98, h, hx("16223a"), hx("22344f"), snow=hx("c9d6f0"))
    mid.save("frost_mid.png")

    near = Layer()
    for x in range(-4, W + 4, 6):
        if 140 < x < 340:
            continue
        edge = min(x, W - x)
        h = r.randint(18, 30) + max(0, 50 - edge) // 2
        pine(near, x + r.randint(-2, 2), 101, h, hx("0d1628"), hx("172642"), snow=hx("dfe8ff"))
    # A few warm windows: a cabin at the treeline.
    cx, cy = 118, 97
    for y in range(cy - 8, cy):
        for x in range(cx - 9, cx + 10):
            near.set(x, y, hx("3a2a2a"))
    for i in range(7):
        for x in range(cx - 11 + i, cx + 12 - i):
            near.set(x, cy - 9 - i, hx("e8eeff") if i < 3 else hx("c8d2ee"))
    for x, y in [(cx - 5, cy - 5), (cx - 4, cy - 5), (cx + 4, cy - 5), (cx + 5, cy - 5)]:
        near.set(x, y, hx("ffc870"))
        near.set(x, y + 1, hx("ff9a3c"))
    near.save("frost_near.png")


# ============================================================================
# V. The Edge — above the clouds before sunrise
# ============================================================================

def edge():
    sky = Layer()
    sky_gradient(sky, [(0.0, hx("1b1a4a")), (0.35, hx("4a3a7e")), (0.62, hx("b56a9e")),
                       (0.82, hx("f2a08e")), (1.0, hx("ffd89a"))])
    stars(sky, 160, 23, 50, [hx("ffffff"), hx("f0e0ff")], 6)
    # The sun about to break the horizon, dead centre over the fairway.
    disc(sky, 240, 88, 12, hx("fff6d0"), hx("ffcf8a"), 34)
    sky.save("edge_sky.png")

    far = Layer()
    # Distant peaks poking through the cloud sea.
    for cx, h_, w_ in [(60, 26, 70), (130, 14, 50), (380, 30, 80), (440, 18, 50)]:
        for x in range(cx - w_ // 2, cx + w_ // 2):
            t = abs(x - cx) / (w_ / 2)
            top = 86 - h_ * (1 - t) ** 1.2
            lit = x < cx
            for y in range(int(top), 92):
                c = hx("7a5a8e") if not lit else hx("a77a9e")
                if y - top < 5:
                    c = hx("f4d6e4") if lit else hx("c4a4c8")
                far.set(x, y, c)
    far.save("edge_far.png")

    clouds = Layer(960)
    r = random.Random(33)
    # A few high wisps.
    for i in range(6):
        cx = i * 160 + r.randint(0, 60)
        cloud(clouds, cx, r.randint(20, 46), r.randint(70, 140), r.randint(3, 6),
              hx("ffd8e0"), hx("e0a0c0"), hx("9a6a9e"), 400 + i, alpha=200)
    clouds.save("edge_clouds.png")

    mid = Layer()
    # The cloud sea: rolling tops, lit gold from the sun behind.
    r = random.Random(43)
    for layer_i, (y_base, col) in enumerate([(88, (hx("ffe0c8"), hx("f0b8c0"), hx("c090b8"))),
                                             (92, (hx("fff0f0"), hx("f2c6d8"), hx("d19ec0")))]):
        x = -20
        while x < W + 30:
            w_ = r.randint(40, 80)
            h_ = r.randint(8, 14) + layer_i * 3
            cloud(mid, x, y_base, w_, h_, *col, 500 + x + layer_i * 1000, flat=False)
            x += int(w_ * 0.6)
    for y in range(92, H):
        for x in range(W):
            mid.set(x, y, hx("fff0f0") if bayer(x, y) > 0.3 else hx("f2c6d8"))
    mid.save("edge_mid.png")


if __name__ == "__main__":
    which = sys.argv[1:] or ["barley", "cliffs", "mesa", "frost", "edge"]
    for name in which:
        globals()[name]()
        print("drew", name)
