"""Small sprites: the pin flag and the room-tab icons.

Drawn at 1x for the 480x270 overlay (they never scale), so every pixel is
placed on purpose. Run:  python3 tools/art/draw_tour_sprites.py
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixel import Canvas, hexc, mix, darken, lighten  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites", "tour")
os.makedirs(OUT, exist_ok=True)

INK = hexc("2a1f2d")


def strip(frames: list[Canvas]) -> Image.Image:
    w = sum(f.w for f in frames)
    h = max(f.h for f in frames)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for f in frames:
        im.alpha_composite(f.image(), (x, h - f.h))
        x += f.w
    return im


# --- flags ---------------------------------------------------------------------

def flag(cloth: list, ribbon: bool, wave: int) -> Canvas:
    cv = Canvas(15, 27)
    pole_x = 3
    # Pole: white with a cool shade side, gold ball finial.
    for y in range(3, 25):
        cv.set(pole_x, y, hexc("f4f1ea"))
        cv.set(pole_x + 1, y, hexc("c9c4bd"))
    cv.set(pole_x, 2, hexc("ffd54a"))
    cv.set(pole_x + 1, 2, hexc("d99a2b"))
    # Cloth: a pennant that ripples between frames.
    lo, mid, hi = cloth
    top = 3
    for x in range(0, 10):
        span = 7 - int(x * 0.62)
        off = [0, 1, 1, 0, 0, -1, -1, 0, 0, 1][(x + wave * 2) % 10] if x > 1 else 0
        for y in range(span):
            yy = top + y + off + (x // 4)
            c = mid
            if y == 0:
                c = hi
            elif y >= span - 1:
                c = lo
            if (x + wave) % 5 == 3 and y > 0:
                c = mix(c, lo, 0.5)
            cv.set(pole_x + 2 + x, yy, c)
    if ribbon:
        # A loose ribbon tied under the cloth — Ratina's mark.
        rb = hexc("fff0f6")
        for i, (dx, dy) in enumerate([(2, 11), (3, 12), (4, 12), (5, 13), (6, 13 + wave), (7, 14 + wave), (8, 14)]):
            cv.set(pole_x + dx, dy, rb if i % 3 else hexc("ffb3d1"))
    cv.outline(INK)
    # Cup shadow at the base.
    for x in range(1, 8):
        cv.set(x, 25, (20, 30, 18, 110))
    cv.set(pole_x, 25, hexc("1b1b1b"))
    cv.set(pole_x + 1, 25, hexc("1b1b1b"))
    return cv


red = [hexc("a8262f"), hexc("e0433f"), hexc("ff7a5c")]
strip([flag(red, False, 0), flag(red, False, 1)]).save(os.path.join(OUT, "flag_red.png"))


# --- HUD icons (12x12) ---------------------------------------------------------------

def icon_coin() -> Canvas:
    cv = Canvas(12, 12)
    cv.ellipse(6, 6, 5, 5, hexc("e8a83a"))
    cv.ellipse(5.5, 5.5, 3.8, 3.8, hexc("ffd45a"))
    cv.rect(5, 3, 6, 8, hexc("c9862a"))
    cv.set(4, 4, hexc("fff2b0"))
    return cv


def icon_book() -> Canvas:
    cv = Canvas(12, 12)
    cv.rect(2, 1, 9, 10, hexc("8a4f35"))
    cv.rect(2, 1, 3, 10, hexc("5e3424"))
    cv.rect(4, 2, 9, 9, hexc("a8634a"))
    cv.rect(5, 3, 8, 4, hexc("f4e2c0"))
    cv.set(9, 2, hexc("e8739f"))
    cv.set(9, 3, hexc("e8739f"))
    cv.set(9, 11, hexc("e8739f"))
    return cv


def icon_ball() -> Canvas:
    cv = Canvas(12, 12)
    cv.ellipse(6, 6, 4.5, 4.5, hexc("ffffff"))
    cv.ellipse(7, 7, 3.2, 3.2, hexc("e4e4ea"))
    cv.ellipse(5.5, 5.5, 3.0, 3.0, hexc("ffffff"))
    cv.set(5, 7, hexc("c9c9d2"))
    cv.set(7, 5, hexc("c9c9d2"))
    cv.set(8, 8, hexc("c9c9d2"))
    return cv


def icon_star() -> Canvas:
    cv = Canvas(12, 12)
    cv.poly([(6, 0), (7.6, 4), (12, 4.3), (8.6, 7), (9.8, 11.5), (6, 9), (2.2, 11.5), (3.4, 7), (0, 4.3), (4.4, 4)], hexc("ffd45a"))
    cv.set(5, 3, hexc("fff2b0"))
    cv.set(5, 4, hexc("fff2b0"))
    return cv


for name, fn in {"i_coin": icon_coin, "i_book": icon_book, "i_ball": icon_ball, "i_star": icon_star}.items():
    cv = fn()
    cv.outline(INK)
    im = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    im.alpha_composite(cv.image(), (1, 1))
    im.save(os.path.join(OUT, f"{name}.png"))


print("wrote", OUT)
