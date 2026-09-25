"""v8 range props: billboards that stand in the rough on each range.

Light from the upper left, a dark selective outline, 3-4 tone ramps.
Run: python3 tools/art/draw_tour_props.py
"""
from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixel import Canvas, hexc, mix  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites", "tour", "props")
os.makedirs(OUT, exist_ok=True)
INK = hexc("241c2a")


def finish(cv: Canvas, name: str, outline=INK):
    cv.outline(outline)
    cv.save(os.path.join(OUT, name + ".png"))


def pine(name, h, greens, trunk, snow=None, seed=1):
    r = random.Random(seed)
    w = int(h * 0.62)
    cv = Canvas(w + 4, h + 4)
    cx = (w + 4) // 2
    tiers = 4
    for t in range(tiers):
        top = 2 + int(t * (h - 6) / tiers * 0.85)
        bot = top + int((h - 6) / tiers * 1.5)
        for y in range(top, min(bot, h - 2)):
            k = (y - top) / max(bot - top, 1)
            half = int(1 + k * (w / 2) * (0.45 + 0.55 * (t + 1) / tiers))
            for x in range(cx - half, cx + half + 1):
                rel = (x - cx) / max(half, 1)
                c = greens[1]
                if rel < -0.35:
                    c = greens[0]
                elif rel > 0.4:
                    c = greens[2]
                if y == bot - 1 or (y > bot - 3 and r.random() < 0.4):
                    c = greens[2]
                if snow and k < 0.35 and rel < 0.5:
                    c = snow[0] if rel < 0 else snow[1]
                cv.set(x, y, c)
    for y in range(h - 3, h + 2):
        cv.set(cx, y, trunk)
        cv.set(cx + 1, y, mix(trunk, INK, 0.3))
    finish(cv, name)


def oak(name, h, greens, trunk, seed=2):
    r = random.Random(seed)
    w = int(h * 0.9)
    cv = Canvas(w + 4, h + 4)
    cx = (w + 4) / 2
    blobs = [(cx, h * 0.38, h * 0.3), (cx - h * 0.22, h * 0.5, h * 0.24), (cx + h * 0.22, h * 0.48, h * 0.25),
             (cx, h * 0.58, h * 0.22)]
    for y in range(cv.h):
        for x in range(cv.w):
            best = None
            for (bx, by, br) in blobs:
                d = math.hypot(x + 0.5 - bx, y + 0.5 - by)
                if d <= br:
                    ny = (y + 0.5 - by) / br
                    nx = (x + 0.5 - bx) / br
                    k = -ny * 0.7 - nx * 0.5
                    best = max(best if best is not None else -9, k)
            if best is None:
                continue
            c = greens[0] if best > 0.45 else (greens[1] if best > -0.2 else greens[2])
            if r.random() < 0.06:
                c = mix(c, greens[2], 0.5)
            cv.set(x, y, c)
    tx = int(cx)
    for y in range(int(h * 0.6), h + 2):
        cv.set(tx, y, trunk)
        cv.set(tx - 1, y, mix(trunk, hexc("ffffff"), 0.15))
    finish(cv, name)


def bush(name, w, greens, flowers=None, seed=3):
    r = random.Random(seed)
    h = int(w * 0.55)
    cv = Canvas(w + 2, h + 2)
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            dy = (y + 0.5 - h) / h
            if dx * dx + dy * dy <= 1.0 + 0.2 * math.sin(x * 1.3):
                k = -dy * 0.3 - dx * 0.4 + (1 - (y / h)) * 0.4
                c = greens[0] if k > 0.55 else (greens[1] if k > 0.2 else greens[2])
                cv.set(x + 1, y + 1, c)
                if flowers and r.random() < 0.07 and y < h - 2:
                    cv.set(x + 1, y + 1, r.choice(flowers))
    finish(cv, name)


def rock(name, w, tones, seed=4, moss=None):
    r = random.Random(seed)
    h = int(w * 0.6)
    cv = Canvas(w + 2, h + 2)
    pts = []
    for i in range(9):
        a = math.pi + i * math.pi / 8
        rr = 1.0 + r.uniform(-0.15, 0.1)
        pts.append((w / 2 + math.cos(a) * w / 2 * rr + 1, h + math.sin(a) * h * rr + 1))
    cv.poly(pts, tones[1])
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.get(x, y) is None:
                continue
            k = (x / w) * 0.6 + (y / h) * 0.5
            c = tones[0] if k < 0.45 else (tones[1] if k < 0.8 else tones[2])
            if moss and y < h * 0.4 and r.random() < 0.5:
                c = moss
            cv.set(x, y, c)
    finish(cv, name)


def saguaro(name, h):
    w = int(h * 0.7)
    cv = Canvas(w + 2, h + 2)
    cx = w // 2
    g0, g1, g2 = hexc("7fb06a"), hexc("5b8f55"), hexc("3f6a44")
    def col(x0, y0, y1, width):
        for y in range(y0, y1):
            for x in range(x0, x0 + width):
                rel = (x - x0) / max(width - 1, 1)
                c = g0 if rel < 0.3 else (g1 if rel < 0.7 else g2)
                if (x - x0) % 2 == 1 and y % 3 == 0:
                    c = mix(c, hexc("f4f0d0"), 0.4)
                cv.set(x, y, c)
    col(cx - 2, 2, h + 1, 5)
    ay = int(h * 0.45)
    col(cx - 6, ay, ay + 3, 4)
    col(cx - 7, ay - int(h * 0.22), ay + 2, 3)
    by = int(h * 0.35)
    col(cx + 3, by, by + 3, 4)
    col(cx + 5, by - int(h * 0.2), by + 2, 3)
    cv.set(cx, 1, hexc("f07aa8"))
    finish(cv, name)


def tumbleweed(name, d):
    cv = Canvas(d + 2, d + 2)
    r = random.Random(9)
    c = d / 2 + 1
    for i in range(70):
        a = r.uniform(0, math.tau)
        rr = r.uniform(0.3, 1.0) * d / 2
        x, y = int(c + math.cos(a) * rr), int(c + math.sin(a) * rr)
        cv.set(x, y, hexc("c9a066") if r.random() < 0.6 else hexc("9a7444"))
    for a in range(0, 360, 20):
        for rr in range(int(d / 2 * 0.6), int(d / 2)):
            x, y = int(c + math.cos(math.radians(a + rr * 9)) * rr), int(c + math.sin(math.radians(a + rr * 9)) * rr)
            cv.set(x, y, hexc("b08850"))
    finish(cv, name, hexc("5a4030"))


def grass_tuft(name, h, tones):
    w = h + 2
    cv = Canvas(w + 2, h + 2)
    r = random.Random(h)
    for blade in range(7):
        x0 = 2 + blade * (w - 2) // 7
        lean = r.choice([-1, 0, 1])
        bh = r.randint(h // 2, h)
        for k in range(bh):
            x = x0 + (lean * k) // 4
            cv.set(x, h + 1 - k, tones[0] if k > bh * 0.6 else tones[1])
    finish(cv, name)


def snowdrift(name, w):
    h = int(w * 0.35)
    cv = Canvas(w + 2, h + 2)
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            top = h * (1 - dx * dx) * (0.9 + 0.1 * math.sin(x * 0.8))
            if h - y <= top:
                c = hexc("ffffff") if dx < 0.1 and y < h * 0.6 else hexc("d6e0f2")
                cv.set(x + 1, y + 1, c)
    finish(cv, name, hexc("7a8aae"))


def sign(name, text_px):
    cv = Canvas(18, 20)
    wood, wood_d = hexc("a8763f"), hexc("7a5230")
    for y in range(9, 20):
        cv.set(8, y, wood_d)
        cv.set(9, y, wood)
    cv.rect(1, 1, 16, 9, hexc("f6efdc"))
    cv.rect(1, 9, 16, 9, hexc("d8ccb0"))
    from pixel import text
    text(cv, 3, 3, text_px, hexc("3f8f4e"))
    finish(cv, name)


def cloud_puff(name, w, tones):
    h = int(w * 0.5)
    cv = Canvas(w + 2, h + 2)
    blobs = [(w * 0.3, h * 0.65, h * 0.45), (w * 0.55, h * 0.45, h * 0.55), (w * 0.78, h * 0.68, h * 0.38)]
    for y in range(cv.h):
        for x in range(cv.w):
            best = None
            for (bx, by, br) in blobs:
                d = math.hypot(x - bx, (y - by) * 1.1)
                if d <= br:
                    best = max(best if best is not None else -9, -(y - by) / br - (x - bx) / br * 0.3)
            if best is None or y > h * 0.9:
                continue
            c = tones[0] if best > 0.35 else (tones[1] if best > -0.2 else tones[2])
            cv.set(x, y, c)
    finish(cv, name, tones[3])


def hay_bale(name, w):
    h = int(w * 0.7)
    cv = Canvas(w + 2, h + 2)
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            dy = (y + 0.5 - h / 2) / (h / 2)
            if dx * dx * 0.6 + dy * dy <= 1.0:
                k = -dx * 0.5 - dy * 0.5
                c = hexc("f2d27a") if k > 0.3 else (hexc("d9b25a") if k > -0.3 else hexc("b08a40"))
                if x % 3 == 0:
                    c = mix(c, hexc("8a6a30"), 0.25)
                cv.set(x + 1, y + 1, c)
    finish(cv, name)


# Barley's
pine("barley_pine", 34, [hexc("4f8a5a"), hexc("3a6f4a"), hexc("2a5238")], hexc("6b4a32"), seed=1)
oak("barley_oak", 30, [hexc("8cbf5c"), hexc("5f9a48"), hexc("3f7040")], hexc("6b4a32"))
bush("barley_bush", 16, [hexc("8cbf5c"), hexc("5f9a48"), hexc("3f7040")], [hexc("fff1b0"), hexc("ff9ab8"), hexc("ffffff")])
hay_bale("barley_hay", 14)
sign("sign_50", "50")
sign("sign_100", "100")
sign("sign_150", "150")
# Cliffs
rock("cliffs_rock", 18, [hexc("d8ccb4"), hexc("a8998a"), hexc("7a6c64")], moss=hexc("8fb060"))
grass_tuft("cliffs_grass", 12, [hexc("d9d68a"), hexc("a4a85a")])
bush("cliffs_gorse", 14, [hexc("b8c860"), hexc("8a9d48"), hexc("5f7438")], [hexc("ffd84a")])
# Mesa
saguaro("mesa_saguaro", 30)
rock("mesa_rock", 18, [hexc("e8906a"), hexc("c0603e"), hexc("8a3f30")])
bush("mesa_scrub", 12, [hexc("b0a868"), hexc("8a8448"), hexc("62603a")])
tumbleweed("mesa_tumbleweed", 11)
# Frost
pine("frost_pine", 36, [hexc("3f6a6a"), hexc("2c5058"), hexc("1d3a44")], hexc("4a3a32"),
     snow=(hexc("ffffff"), hexc("c8d6ee")), seed=5)
snowdrift("frost_drift", 22)
rock("frost_rock", 16, [hexc("b8c4dc"), hexc("8894b0"), hexc("5a6480")], moss=hexc("ffffff"))
# Edge
cloud_puff("edge_cloud", 40, [hexc("fff6f8"), hexc("f6d0e0"), hexc("d8a8c8"), hexc("a878a8")])
cloud_puff("edge_cloud_s", 26, [hexc("fff6f8"), hexc("f6d0e0"), hexc("d8a8c8"), hexc("a878a8")])
print("wrote", OUT)
