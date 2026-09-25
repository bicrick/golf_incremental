"""v8 small sprites: flags, lanterns, picker cart, keepsake icons.

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
pink = [hexc("c2457a"), hexc("f07aa8"), hexc("ffc0d8")]
strip([flag(red, False, 0), flag(red, False, 1)]).save(os.path.join(OUT, "flag_red.png"))
strip([flag(pink, True, 0), flag(pink, True, 1)]).save(os.path.join(OUT, "flag_pink.png"))


# --- lanterns --------------------------------------------------------------------

def lantern(lit: bool) -> Canvas:
    cv = Canvas(13, 27)
    wood, wood_d = hexc("6b4a32"), hexc("4a3222")
    for y in range(9, 26):
        cv.set(6, y, wood)
        cv.set(7, y, wood_d)
    cv.rect(2, 7, 11, 7, wood_d)  # arm
    # Lantern box hanging from the arm.
    frame = hexc("2f2f3a")
    glass = hexc("ffd27a") if lit else hexc("5b6780")
    glass_hi = hexc("fff4c9") if lit else hexc("7f8ca6")
    cv.rect(2, 8, 5, 8, frame)
    cv.rect(1, 9, 6, 15, frame)
    cv.rect(2, 10, 5, 14, glass)
    cv.set(2, 10, glass_hi)
    cv.set(3, 10, glass_hi)
    if lit:
        cv.set(3, 12, hexc("ff9a3c"))
        cv.set(4, 12, hexc("ff9a3c"))
        cv.set(3, 13, hexc("fff4c9"))
    cv.rect(2, 16, 5, 16, frame)
    # Snow cap on the arm and post top.
    for x in range(2, 12):
        cv.set(x, 6, hexc("f4f8ff"))
    cv.set(6, 8, hexc("f4f8ff"))
    cv.outline(INK)
    for x in range(3, 11):
        cv.set(x, 26, (20, 24, 40, 110))
    return cv


lantern(False).save(os.path.join(OUT, "lantern_off.png"))
lantern(True).save(os.path.join(OUT, "lantern_on.png"))


# --- picker cart (seen from above-behind) -------------------------------------------

def cart() -> Canvas:
    cv = Canvas(24, 18)
    body, body_d, body_h = hexc("3f8f4e"), hexc("2c6a3a"), hexc("6cc27a")
    cv.rect(3, 6, 20, 13, body)
    cv.rect(3, 12, 20, 13, body_d)
    cv.rect(3, 6, 20, 6, body_h)
    # Wire cage with balls.
    cage = hexc("b9c2c8")
    for x in range(5, 19, 3):
        for y in range(1, 6):
            cv.set(x, y, cage)
    cv.rect(5, 1, 18, 1, cage)
    for bx, by in [(7, 4), (10, 3), (13, 4), (16, 3), (9, 5), (15, 5), (12, 5)]:
        cv.set(bx, by, hexc("ffffff"))
    # Wheels.
    for wx in (4, 18):
        cv.rect(wx, 13, wx + 2, 15, hexc("24242a"))
        cv.set(wx + 1, 13, hexc("5a5a66"))
    # Seat / the rat's tail sticking out the back.
    cv.rect(10, 8, 13, 10, hexc("f4e2c0"))
    cv.set(21, 10, hexc("ef9fa0"))
    cv.set(22, 11, hexc("ef9fa0"))
    cv.set(23, 11, hexc("ef9fa0"))
    cv.outline(INK)
    return cv


cart().save(os.path.join(OUT, "cart.png"))


# --- keepsakes (14x14) -----------------------------------------------------------------

def ks_tee() -> Canvas:
    cv = Canvas(14, 14)
    w, wd = hexc("e8c38a"), hexc("b68a52")
    cv.rect(4, 2, 9, 3, w)
    cv.rect(4, 3, 9, 3, wd)
    for y in range(4, 12):
        cv.set(6, y, w)
        cv.set(7, y, wd)
    cv.set(6, 12, wd)
    cv.set(5, 6, hexc("7a4a2a"))  # carved B
    cv.set(5, 7, hexc("7a4a2a"))
    return cv


def ks_key() -> Canvas:
    cv = Canvas(14, 14)
    g, gd = hexc("e2b84a"), hexc("a8792a")
    cv.ellipse(4.5, 5, 3, 3, g)
    cv.set(4, 5, None)
    cv.set(5, 5, None)
    cv.set(4, 4, None)
    for x in range(7, 13):
        cv.set(x, 5, g)
        cv.set(x, 6, gd)
    cv.set(11, 7, gd)
    cv.set(12, 7, gd)
    cv.set(9, 7, gd)
    return cv


def ks_feather() -> Canvas:
    cv = Canvas(14, 14)
    for i in range(11):
        x, y = 2 + i, 12 - i
        cv.set(x, y, hexc("8e8a86"))
        if 2 < i < 10:
            cv.set(x - 1, y - 1, hexc("f4f4f2"))
            cv.set(x - 2, y - 1, hexc("dcdcda"))
            cv.set(x + 1, y + 1, hexc("f4f4f2"))
    return cv


def ks_bottle() -> Canvas:
    cv = Canvas(14, 14)
    gl, gld = hexc("7fc6b0"), hexc("4f9582")
    cv.rect(3, 5, 10, 10, gl)
    cv.rect(3, 9, 10, 10, gld)
    cv.rect(10, 6, 12, 8, gl)
    cv.set(13, 7, hexc("a0703c"))
    cv.rect(5, 6, 8, 8, hexc("f2e6c8"))  # the note
    cv.set(4, 6, hexc("d9fff2"))
    return cv


def ks_rattle() -> Canvas:
    cv = Canvas(14, 14)
    for i, r in enumerate([3, 2.6, 2.2, 1.8, 1.4]):
        cv.ellipse(3 + i * 2.2, 7, r, r, hexc("d9b27a") if i % 2 == 0 else hexc("b88c52"))
    return cv


def ks_postcard() -> Canvas:
    cv = Canvas(14, 14)
    cv.rect(1, 3, 12, 10, hexc("f6ecd4"))
    cv.rect(8, 4, 11, 6, hexc("5aa0d8"))  # stamp
    cv.set(9, 5, hexc("ffffff"))
    for x in range(2, 7):
        cv.set(x, 5, hexc("8a7a6a"))
        cv.set(x, 7, hexc("8a7a6a"))
    cv.rect(2, 9, 11, 9, hexc("e3d2b0"))
    return cv


def ks_mitten() -> Canvas:
    cv = Canvas(14, 14)
    p, pd = hexc("f07aa8"), hexc("c2457a")
    cv.ellipse(7, 6, 4, 4.5, p)
    cv.ellipse(3.2, 7, 1.6, 2.2, p)
    cv.rect(4, 10, 10, 12, hexc("fff0f6"))
    cv.rect(4, 12, 10, 12, pd)
    cv.set(6, 4, hexc("ffc0d8"))
    return cv


def ks_thermos() -> Canvas:
    cv = Canvas(14, 14)
    r, rd = hexc("d24a3c"), hexc("9c2f27")
    cv.rect(4, 3, 9, 12, r)
    cv.rect(8, 3, 9, 12, rd)
    cv.rect(4, 1, 9, 2, hexc("c9c4bd"))
    cv.rect(4, 6, 9, 7, hexc("f2e6c8"))
    # Steam.
    cv.set(6, 0, hexc("ffffff", 140))
    cv.set(11, 2, hexc("ffffff", 110))
    return cv


def ks_cap() -> Canvas:
    cv = Canvas(14, 14)
    g, gd = hexc("7a8a5a"), hexc("56643e")
    cv.ellipse(7, 7, 5, 3.6, g)
    cv.rect(2, 8, 12, 9, gd)
    cv.rect(9, 9, 13, 10, gd)
    cv.set(7, 4, hexc("a3b57a"))
    cv.set(5, 5, hexc("a3b57a"))
    return cv


def ks_photo() -> Canvas:
    cv = Canvas(14, 14)
    cv.rect(1, 2, 12, 11, hexc("f4efe4"))
    cv.rect(2, 3, 11, 9, hexc("9fc0a4"))
    cv.rect(2, 3, 11, 5, hexc("c9e0f0"))
    for x, c in [(4, "6b5a4a"), (7, "f07aa8"), (9, "8a8a8a")]:
        cv.set(x, 6, hexc(c))
        cv.set(x, 7, hexc(c))
        cv.set(x, 8, hexc(c))
    return cv


KEEPSAKES = {
    "k_tee": ks_tee, "k_key": ks_key, "k_feather": ks_feather, "k_bottle": ks_bottle,
    "k_rattle": ks_rattle, "k_postcard": ks_postcard, "k_mitten": ks_mitten,
    "k_thermos": ks_thermos, "k_cap": ks_cap, "k_photo": ks_photo,
}
for name, fn in KEEPSAKES.items():
    cv = fn()
    cv.outline(INK)
    cv.save(os.path.join(OUT, f"{name}.png"))


# --- HUD icons (12x12) ---------------------------------------------------------------

def icon_coin() -> Canvas:
    cv = Canvas(12, 12)
    cv.ellipse(6, 6, 5, 5, hexc("e8a83a"))
    cv.ellipse(5.5, 5.5, 3.8, 3.8, hexc("ffd45a"))
    cv.rect(5, 3, 6, 8, hexc("c9862a"))
    cv.set(4, 4, hexc("fff2b0"))
    return cv


def icon_bag() -> Canvas:
    cv = Canvas(12, 12)
    cv.rect(3, 3, 8, 10, hexc("3f8f4e"))
    cv.rect(3, 3, 4, 10, hexc("6cc27a"))
    cv.rect(2, 2, 9, 3, hexc("2c6a3a"))
    cv.rect(4, 0, 4, 2, hexc("b9c2c8"))
    cv.rect(7, 0, 7, 2, hexc("8e969c"))
    cv.rect(5, 6, 7, 7, hexc("f4e2c0"))
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


def icon_map() -> Canvas:
    cv = Canvas(12, 12)
    cv.poly([(1, 2), (4, 1), (8, 2), (11, 1), (11, 10), (8, 11), (4, 10), (1, 11)], hexc("efe2c0"))
    cv.rect(4, 1, 4, 10, hexc("d8c79c"))
    cv.rect(8, 2, 8, 11, hexc("d8c79c"))
    for x, y in [(2, 8), (3, 7), (5, 6), (6, 5), (7, 5)]:
        cv.set(x, y, hexc("c2453c"))
    cv.set(9, 3, hexc("c2453c"))
    cv.set(10, 4, hexc("c2453c"))
    cv.set(9, 5, hexc("c2453c"))
    cv.set(10, 3, hexc("c2453c"))
    return cv


def icon_gear() -> Canvas:
    cv = Canvas(12, 12)
    cv.ellipse(6, 6, 4.2, 4.2, hexc("8e969c"))
    for x, y in [(5, 0), (6, 0), (5, 11), (6, 11), (0, 5), (0, 6), (11, 5), (11, 6), (2, 2), (9, 2), (2, 9), (9, 9)]:
        cv.set(x, y, hexc("8e969c"))
    cv.ellipse(6, 6, 1.6, 1.6, hexc("f6efdc"))
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


for name, fn in {"i_coin": icon_coin, "i_bag": icon_bag, "i_book": icon_book, "i_map": icon_map,
                 "i_gear": icon_gear, "i_ball": icon_ball, "i_star": icon_star}.items():
    cv = fn()
    cv.outline(INK)
    im = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    im.alpha_composite(cv.image(), (1, 1))
    im.save(os.path.join(OUT, f"{name}.png"))


# --- map token: the rat's head in his green cap (16x16) -------------------------

def token() -> Canvas:
    cv = Canvas(16, 16)
    fur, fur_d, fur_h = hexc("7a6a72"), hexc("5a4c56"), hexc("9a8a90")
    pink = hexc("f2a0a8")
    cv.ellipse(3.5, 6, 3, 3, fur_d)
    cv.ellipse(12.5, 6, 3, 3, fur_d)
    cv.ellipse(3.5, 6, 1.8, 1.8, pink)
    cv.ellipse(12.5, 6, 1.8, 1.8, pink)
    cv.ellipse(8, 9.5, 5, 4.6, fur)
    cv.ellipse(7, 8.5, 3, 2.5, fur_h)
    cv.set(6, 10, hexc("241c2a"))
    cv.set(10, 10, hexc("241c2a"))
    cv.set(8, 12, hexc("e07a8a"))
    cv.rect(4, 4, 11, 6, hexc("3f8f4e"))
    cv.rect(5, 3, 10, 3, hexc("6cc27a"))
    cv.rect(10, 6, 14, 7, hexc("2c6a3a"))
    return cv


tk = token()
tk.outline(INK)
tk.save(os.path.join(OUT, "token.png"))

print("wrote", OUT)
