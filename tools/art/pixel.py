"""Tiny pixel-art toolkit for hand-authored sprites (v5 story finds).

Sprites are drawn on a small grid of RGBA tuples, then finished with a dark
selective outline to match the PixelLab house style (chunky 1px outline, 3-4
tone ramps, warm top-left light).
"""
from __future__ import annotations

import math
from PIL import Image

Color = tuple


def hexc(h: str, a: int = 255) -> Color:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a: Color, b: Color, t: float) -> Color:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def darken(c: Color, t: float) -> Color:
    return mix(c, (20, 14, 22, c[3]), t)


def lighten(c: Color, t: float) -> Color:
    return mix(c, (255, 250, 230, c[3]), t)


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.px: list[list[Color | None]] = [[None] * w for _ in range(h)]

    # --- primitives -------------------------------------------------------
    def set(self, x: int, y: int, c: Color | None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x: int, y: int) -> Color | None:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def rect(self, x0: int, y0: int, x1: int, y1: int, c: Color) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c: Color) -> None:
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / max(rx, 0.01)
                dy = (y + 0.5 - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, c)

    def line(self, x0: int, y0: int, x1: int, y1: int, c: Color, w: int = 1) -> None:
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            t = i / n
            x = round(x0 + (x1 - x0) * t)
            y = round(y0 + (y1 - y0) * t)
            for ox in range(w):
                for oy in range(w):
                    self.set(x + ox, y + oy, c)

    def poly(self, pts: list[tuple[float, float]], c: Color) -> None:
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            yc = y + 0.5
            xs = []
            for i in range(len(pts)):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                    self.set(x, y, c)

    def replace_in(self, pred, fn) -> None:
        """Recolor pixels where pred(x, y, c) is true with fn(x, y, c)."""
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None and pred(x, y, c):
                    self.px[y][x] = fn(x, y, c)

    # --- finishing --------------------------------------------------------
    def shade_sphere(self, cx: float, cy: float, r: float, ramp: list[Color]) -> None:
        """Fill a disc with a lit ramp (light from top-left)."""
        lx, ly = -0.55, -0.65
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                dx = (x + 0.5 - cx) / r
                dy = (y + 0.5 - cy) / r
                d2 = dx * dx + dy * dy
                if d2 > 1.0:
                    continue
                dz = math.sqrt(1.0 - d2)
                lit = max(0.0, (dx * lx + dy * ly + dz * 0.55) / 1.0)
                idx = min(len(ramp) - 1, int((1.0 - min(lit, 1.0)) * len(ramp)))
                self.set(x, y, ramp[idx])

    def outline(self, c: Color, diagonal: bool = False, inner_ok: bool = True) -> None:
        """Add a 1px outline in transparent pixels bordering the shape."""
        add = []
        nbrs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            nbrs += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    continue
                for dx, dy in nbrs:
                    n = self.get(x + dx, y + dy)
                    if n is not None and n[3] > 0 and n != c:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y][x] = c

    def selective_outline(self, base: Color, strength: float = 0.72) -> None:
        """Outline tinted by the neighbor colour (softer than pure black)."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    continue
                for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                    n = self.get(x + dx, y + dy)
                    if n is not None and n[3] > 200:
                        add.append((x, y, n))
                        break
        for x, y, n in add:
            self.px[y][x] = mix(mix(n, base, strength), base, 0.35)

    def shadow_blob(self, cx: float, cy: float, rx: float, ry: float, a: int = 90) -> None:
        """Soft ground shadow under an object (only in empty pixels)."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0 and self.get(x, y) is None:
                    self.set(x, y, (20, 36, 18, a))

    def image(self, scale: int = 1) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    im.putpixel((x, y), c)
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        return im

    def save(self, path: str) -> None:
        self.image().save(path)


# Tiny 3x5 pixel font for carved / painted signage.
FONT_3X5 = {
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
    "8": ["111", "101", "111", "101", "111"],
    "A": ["010", "101", "111", "101", "101"],
    "E": ["111", "100", "110", "100", "111"],
    "H": ["101", "101", "111", "101", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "O": ["111", "101", "101", "101", "111"],
    "P": ["110", "101", "110", "100", "100"],
    "R": ["110", "101", "110", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "D": ["110", "101", "101", "101", "110"],
    "S": ["111", "100", "111", "001", "111"],
    ".": ["000", "000", "000", "000", "010"],
    " ": ["000", "000", "000", "000", "000"],
}


def text(cv: Canvas, x: int, y: int, s: str, c: Color, shadow: Color | None = None) -> int:
    for ch in s:
        glyph = FONT_3X5.get(ch.upper(), FONT_3X5[" "])
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    if shadow is not None:
                        cv.set(x + gx, y + gy + 1, shadow)
                    cv.set(x + gx, y + gy, c)
        x += 4
    return x


def text_width(s: str) -> int:
    return len(s) * 4 - 1


# --- v5 quality passes ---------------------------------------------------------
import colorsys
import random as _random


def shift(c: Color, dl: float, hue_shift: float = 0.0, ds: float = 0.0) -> Color:
    """Lighten/darken with hue shifting (shadows cool, highlights warm)."""
    r, g, b, a = c
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    l = min(max(l + dl, 0.0), 1.0)
    h = (h + hue_shift) % 1.0
    s = min(max(s + ds, 0.0), 1.0)
    rr, gg, bb = colorsys.hls_to_rgb(h, l, s)
    return (int(rr * 255), int(gg * 255), int(bb * 255), a)


def _toward(h: float, target: float, amt: float) -> float:
    d = ((target - h + 0.5) % 1.0) - 0.5
    return (h + d * amt) % 1.0


def warm(c: Color, dl: float) -> Color:
    r, g, b, a = c
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    return shift(c, dl, _toward(h, 0.13, 0.12) - h, 0.04)


def cool(c: Color, dl: float) -> Color:
    r, g, b, a = c
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    return shift(c, -dl, _toward(h, 0.72, 0.16) - h, -0.02)


def auto_light(cv: "Canvas", reach: int = 2, hi: float = 0.07, lo: float = 0.09, skip=None) -> None:
    """Bevel every form: pixels near an up/left edge get a warm highlight, near a
    down/right edge a cool shadow. Keeps the light direction consistent."""
    src = [row[:] for row in cv.px]

    def empty(x, y):
        if 0 <= x < cv.w and 0 <= y < cv.h:
            p = src[y][x]
            return p is None or p[3] < 128
        return True

    for y in range(cv.h):
        for x in range(cv.w):
            c = src[y][x]
            if c is None or c[3] < 200:
                continue
            if skip is not None and skip(x, y, c):
                continue
            up = any(empty(x, y - k) or empty(x - k, y) for k in range(1, reach + 1))
            dn = any(empty(x, y + k) or empty(x + k, y) for k in range(1, reach + 1))
            if up and not dn:
                cv.px[y][x] = warm(c, hi)
            elif dn and not up:
                cv.px[y][x] = cool(c, lo)


def grain(cv: "Canvas", pred, amount: float = 0.05, density: float = 0.22, seed: int = 1, streak: int = 0) -> None:
    """Material texture: speckle (stone/paper) or horizontal streaks (wood)."""
    rnd = _random.Random(seed)
    for y in range(cv.h):
        run = 0
        for x in range(cv.w):
            c = cv.px[y][x]
            if c is None or c[3] < 200 or not pred(x, y, c):
                run = 0
                continue
            if run > 0:
                cv.px[y][x] = cool(c, amount)
                run -= 1
            elif rnd.random() < density:
                if streak > 0:
                    run = rnd.randint(1, streak)
                    cv.px[y][x] = cool(c, amount)
                else:
                    cv.px[y][x] = warm(c, amount) if rnd.random() < 0.4 else cool(c, amount)


def ground_contact(cv: "Canvas", rows: int = 2, amount: float = 0.10) -> None:
    """Darken the lowest opaque pixels of each column (contact shadow)."""
    for x in range(cv.w):
        found = 0
        for y in range(cv.h - 1, -1, -1):
            c = cv.px[y][x]
            if c is None or c[3] < 200:
                if found:
                    break
                continue
            if found < rows:
                cv.px[y][x] = cool(c, amount * (1.0 - found / rows))
            found += 1


def is_green(c) -> bool:
    r, g, b, _ = c
    return g > r + 20 and g > b + 20
