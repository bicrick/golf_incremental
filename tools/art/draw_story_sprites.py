"""Draw v5 story-find sprites into assets/sprites/story/.

Run from the repo root:  python3 tools/art/draw_story_sprites.py [--preview out.png]
Requires Pillow. Every sprite is authored procedurally so it can be re-tuned.
"""
from __future__ import annotations

import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixel import Canvas, darken, hexc, lighten, mix, text, text_width  # noqa: E402

OUT = os.path.join("assets", "sprites", "story")

OUTLINE = hexc("2a1a1c")
# Shared ramps -----------------------------------------------------------------
PAPER = [hexc("fbf3dc"), hexc("efe2bd"), hexc("d9c79a"), hexc("b39f72")]
WOOD = [hexc("c98e55"), hexc("a86c3c"), hexc("80502c"), hexc("5a371f")]
DARKWOOD = [hexc("8a4b2e"), hexc("6e3a22"), hexc("522918"), hexc("3a1c12")]
STONE = [hexc("d8d6c8"), hexc("b4b2a4"), hexc("8e8c80"), hexc("686860")]
MOSS = [hexc("9cc45a"), hexc("6fa040"), hexc("4d7c2e")]
RUST = [hexc("c9794a"), hexc("a2552f"), hexc("7a3b22"), hexc("522615")]
BRONZE = [hexc("ffe08a"), hexc("e6b24a"), hexc("b87f2c"), hexc("7d5220")]
VERDIGRIS = [hexc("9fd0b0"), hexc("6fa889"), hexc("4d7d66"), hexc("33574a")]
GRASS = [hexc("8fd35a"), hexc("5fae3e"), hexc("3f8a2f"), hexc("2c6624")]
DIRT = [hexc("a67b52"), hexc("86603d"), hexc("66472c"), hexc("47301e")]
PINK = [hexc("ffc2d6"), hexc("f4879f"), hexc("d65d7c"), hexc("9e3f5a")]
WHITE = [hexc("ffffff"), hexc("eceae4"), hexc("c9c6bd"), hexc("9c998f")]
METAL = [hexc("f4f6f8"), hexc("c8ced4"), hexc("939ba4"), hexc("5f666e")]
RED = [hexc("ff6b5a"), hexc("e0402f"), hexc("a82a22"), hexc("6e1a17")]
GLOW = [hexc("fff6c2"), hexc("ffd86a"), hexc("f2a93b")]
WATER = [hexc("bfe8ff"), hexc("7cc3ea"), hexc("4d93c4"), hexc("2f6696")]
CAP_GREEN = [hexc("5cc06a"), hexc("3a9a4e"), hexc("2a7438")]


def tuft(cv: Canvas, x: int, y: int, h: int = 3) -> None:
    cv.set(x, y, GRASS[2])
    for i in range(1, h):
        cv.set(x - 1, y - i, GRASS[1])
        cv.set(x + 1, y - i + 1, GRASS[1])
    cv.set(x, y - 1, GRASS[0])


def finish(cv: Canvas) -> Canvas:
    cv.selective_outline(OUTLINE, 0.78)
    return cv


# ---------------------------------------------------------------------------
def scorecard() -> Canvas:
    """Torn scorecard lying tilted in the grass."""
    cv = Canvas(34, 26)
    pts = [(4, 9), (25, 3), (30, 16), (22, 18), (20, 21), (17, 19), (9, 22)]
    cv.poly(pts, PAPER[0])
    # shading bands (paper curl)
    cv.replace_in(lambda x, y, c: y > 16 - (x - 4) * 0.25, lambda x, y, c: PAPER[1])
    cv.replace_in(lambda x, y, c: x < 8, lambda x, y, c: PAPER[1])
    # grid lines of the card (tilted rows)
    for row in range(3):
        for x in range(7, 28):
            y = int(9 + row * 4 - (x - 4) * 0.27 + 1)
            if cv.get(x, y) is not None:
                cv.set(x, y, hexc("9fb7a0"))
    for col in (12, 17, 22):
        for y in range(3, 22):
            yy = y
            xx = col + int((y - 10) * 0.3)
            if cv.get(xx, yy) is not None and cv.get(xx, yy) != hexc("9fb7a0"):
                cv.set(xx, yy, hexc("b8c9b6"))
    # pencil scribble
    for x, y in [(9, 12), (10, 11), (11, 12), (12, 11), (14, 10), (15, 11), (16, 10), (19, 13), (20, 12), (21, 13)]:
        if cv.get(x, y) is not None:
            cv.set(x, y, hexc("5b5a66"))
    # red "1" in the corner box
    for x, y in [(23, 7), (24, 6), (24, 7), (24, 8), (24, 9)]:
        cv.set(x, y, RED[1])
    finish(cv)
    tuft(cv, 3, 24)
    tuft(cv, 29, 22)
    tuft(cv, 15, 25, 2)
    return cv


def ratina_bag() -> Canvas:
    """Pink-and-white golf bag propped on its stand, club heads poking out."""
    cv = Canvas(36, 50)
    cv.shadow_blob(18, 46, 13, 3)
    # clubs sticking out (behind body)
    for i, (x, top, head) in enumerate([(12, 4, METAL), (17, 2, DARKWOOD), (22, 5, METAL)]):
        cv.rect(x, top + 3, x, 14, METAL[2])
        if head is DARKWOOD:
            cv.ellipse(x + 1, top + 2, 3.2, 2.4, DARKWOOD[1])
            cv.set(x, top + 1, DARKWOOD[0])
            cv.set(x + 1, top + 1, DARKWOOD[0])
        else:
            cv.rect(x - 1, top, x + 2, top + 2, head[1])
            cv.set(x - 1, top, head[0])
    # pink head cover on one club
    cv.ellipse(27, 8, 3.2, 3.6, PINK[1])
    cv.set(26, 6, PINK[0]); cv.set(27, 6, PINK[0])
    cv.set(27, 4, WHITE[0]); cv.set(28, 5, WHITE[0])  # pompom
    cv.rect(27, 11, 27, 14, METAL[2])
    # bag body (slightly leaning)
    body = [(9, 14), (27, 13), (28, 42), (10, 43)]
    cv.poly(body, PINK[1])
    # vertical shading: light left, dark right
    cv.replace_in(lambda x, y, c: c == PINK[1] and x <= 12, lambda x, y, c: PINK[0])
    cv.replace_in(lambda x, y, c: c == PINK[1] and x >= 24, lambda x, y, c: PINK[2])
    # white top collar + bottom
    cv.rect(9, 14, 27, 17, WHITE[1])
    cv.rect(9, 14, 12, 17, WHITE[0])
    cv.rect(24, 14, 27, 17, WHITE[2])
    cv.rect(10, 39, 28, 43, WHITE[1])
    cv.rect(24, 39, 28, 43, WHITE[2])
    # pocket with zipper + stripe
    cv.rect(13, 24, 23, 33, PINK[2])
    cv.rect(13, 24, 23, 24, PINK[3])
    cv.rect(13, 28, 23, 28, WHITE[1])
    cv.set(22, 26, BRONZE[1])
    # little heart patch
    for x, y in [(15, 20), (17, 20), (14, 21), (15, 21), (16, 21), (17, 21), (18, 21), (15, 22), (16, 22), (17, 22), (16, 23)]:
        cv.set(x, y, WHITE[0])
    # strap
    cv.line(8, 19, 6, 30, PINK[3])
    cv.line(6, 30, 9, 36, PINK[3])
    # stand legs
    cv.line(27, 30, 32, 45, METAL[2])
    cv.line(25, 32, 29, 46, METAL[3])
    finish(cv)
    tuft(cv, 6, 47)
    tuft(cv, 31, 48)
    return cv


def range_bell(rung: bool) -> Canvas:
    """Wooden post frame with a hanging bell. Rusty/verdigris until rung."""
    cv = Canvas(40, 58)
    cv.shadow_blob(20, 54, 15, 3)
    # posts
    for x in (7, 31):
        cv.rect(x, 8, x + 2, 54, WOOD[1])
        cv.rect(x, 8, x, 54, WOOD[0])
        cv.rect(x + 2, 8, x + 2, 54, WOOD[2])
    # cross beam with a little roof
    cv.poly([(3, 8), (20, 1), (37, 8), (37, 10), (3, 10)], DARKWOOD[1])
    cv.rect(3, 9, 37, 10, DARKWOOD[2])
    cv.line(4, 7, 20, 1, DARKWOOD[0])
    cv.rect(6, 12, 34, 13, WOOD[2])
    # rope
    cv.rect(19, 14, 20, 18, hexc("d9c79a"))
    ramp = BRONZE if rung else VERDIGRIS
    # bell (flared)
    cv.poly([(15, 19), (24, 19), (26, 30), (29, 34), (10, 34), (13, 30)], ramp[1])
    cv.replace_in(lambda x, y, c: c == ramp[1] and x <= 15, lambda x, y, c: ramp[0])
    cv.replace_in(lambda x, y, c: c == ramp[1] and x >= 23, lambda x, y, c: ramp[2])
    cv.rect(10, 33, 29, 34, ramp[3])
    cv.rect(16, 20, 16, 28, lighten(ramp[0], 0.4))
    if not rung:
        # rust speckles
        rnd = random.Random(7)
        for _ in range(14):
            x, y = rnd.randint(12, 27), rnd.randint(20, 33)
            if cv.get(x, y) is not None:
                cv.set(x, y, RUST[rnd.randint(1, 2)])
    # clapper
    cv.rect(19, 35, 20, 37, ramp[3])
    # pull rope hanging
    cv.line(27, 35, 28, 46, hexc("d9c79a"))
    cv.set(28, 47, hexc("b39f72"))
    finish(cv)
    if rung:
        # ring lines
        for x, y in [(6, 24), (5, 26), (6, 28), (33, 24), (34, 26), (33, 28)]:
            cv.set(x, y, GLOW[0])
    tuft(cv, 5, 56)
    tuft(cv, 36, 56)
    tuft(cv, 22, 57, 2)
    return cv


def picker_cart() -> Canvas:
    """Half-buried rusty ball-picker cart with a wire basket of balls."""
    cv = Canvas(58, 40)
    # dirt mound it's sunk into
    cv.ellipse(29, 33, 27, 6, DIRT[1])
    cv.replace_in(lambda x, y, c: c == DIRT[1] and y <= 30, lambda x, y, c: DIRT[0])
    cv.replace_in(lambda x, y, c: c == DIRT[1] and y >= 36, lambda x, y, c: DIRT[2])
    # cart body (tilted trapezoid)
    cv.poly([(8, 16), (44, 12), (47, 30), (10, 33)], RUST[1])
    cv.replace_in(lambda x, y, c: c == RUST[1] and y <= 17, lambda x, y, c: RUST[0])
    cv.replace_in(lambda x, y, c: c == RUST[1] and y >= 27, lambda x, y, c: RUST[2])
    # faded paint stripe
    cv.line(10, 22, 45, 18, hexc("d7c16a"))
    cv.line(10, 23, 45, 19, hexc("b39a47"))
    # wire basket (back rail), a heap of balls, then the front rail
    cv.line(11, 6, 42, 1, METAL[3])
    for i, (bx, by) in enumerate([(15, 11), (20, 10), (25, 9), (30, 8), (35, 8), (40, 7),
                                  (18, 7), (23, 6), (28, 5), (33, 5), (38, 4)]):
        cv.shade_sphere(bx, by, 2.7, WHITE)
    for x in range(12, 43, 5):
        cv.set(x, 13 - int((x - 11) * 0.16), METAL[2])
    cv.line(11, 13, 43, 8, METAL[2])
    # handle
    cv.line(44, 13, 54, 4, METAL[2])
    cv.line(52, 3, 56, 5, METAL[1])
    # wheel peeking out of dirt
    cv.ellipse(17, 32, 5, 5, hexc("3a3a40"))
    cv.ellipse(17, 32, 2, 2, METAL[2])
    cv.rect(10, 34, 26, 38, DIRT[1])
    # moss on the cart
    for x, y in [(12, 17), (13, 17), (13, 16), (40, 14), (41, 14), (41, 13), (28, 31), (29, 31)]:
        cv.set(x, y, MOSS[1])
    finish(cv)
    tuft(cv, 4, 34)
    tuft(cv, 53, 33)
    tuft(cv, 33, 39, 2)
    return cv


def rattling_burrow() -> Canvas:
    """Earth mound with a dark hole and two curious eyes."""
    cv = Canvas(48, 34)
    cv.ellipse(24, 22, 22, 11, DIRT[1])
    cv.replace_in(lambda x, y, c: y < 17, lambda x, y, c: DIRT[0])
    cv.replace_in(lambda x, y, c: y > 28, lambda x, y, c: DIRT[2])
    # grassy cap on the mound
    cv.ellipse(24, 14, 17, 5, GRASS[1])
    cv.replace_in(lambda x, y, c: c == GRASS[1] and y <= 11, lambda x, y, c: GRASS[0])
    # hole
    cv.ellipse(24, 24, 9, 7, hexc("1e1418"))
    cv.ellipse(24, 23, 7, 5, hexc("140c10"))
    cv.rect(15, 28, 33, 30, DIRT[2])  # lip
    # eyes
    for ex in (21, 27):
        cv.set(ex, 23, hexc("fff6c2"))
        cv.set(ex + 1, 23, hexc("ffd86a"))
        cv.set(ex, 24, hexc("ffd86a"))
    # pebbles
    for x, y in [(8, 26), (40, 25), (37, 29), (11, 30)]:
        cv.set(x, y, STONE[1])
        cv.set(x + 1, y, STONE[2])
    # a golf ball stashed by the entrance
    cv.shade_sphere(36, 27, 2.4, WHITE)
    finish(cv)
    tuft(cv, 10, 11)
    tuft(cv, 30, 9)
    tuft(cv, 43, 14)
    return cv


def barley_spoon() -> Canvas:
    """Wooden 'spoon' (3-wood) stuck head-down in the turf like a flag."""
    cv = Canvas(28, 60)
    cv.shadow_blob(14, 56, 9, 2)
    # grip (top), shaft, head buried at bottom with divot
    cv.rect(12, 2, 15, 13, hexc("3a2a26"))
    cv.rect(12, 2, 12, 13, hexc("5c463e"))
    for y in range(3, 13, 2):
        cv.set(13, y, hexc("5c463e"))
    cv.rect(13, 14, 14, 44, METAL[1])
    cv.rect(13, 14, 13, 44, METAL[0])
    # hosel + visible heel of wooden head
    cv.rect(12, 44, 15, 47, DARKWOOD[2])
    cv.poly([(9, 47), (19, 46), (21, 52), (8, 53)], WOOD[1])
    cv.replace_in(lambda x, y, c: c == WOOD[1] and x <= 11, lambda x, y, c: WOOD[0])
    cv.replace_in(lambda x, y, c: c == WOOD[1] and x >= 18, lambda x, y, c: WOOD[2])
    cv.line(10, 49, 18, 48, hexc("f0d9a0"))  # brass sole plate glint
    # divot dirt
    cv.ellipse(14, 54, 9, 3, DIRT[1])
    cv.ellipse(14, 53, 6, 1.5, DIRT[0])
    # little ribbon tied on the grip
    cv.rect(15, 6, 18, 7, RED[1])
    cv.line(18, 7, 21, 11, RED[2])
    cv.line(17, 7, 19, 12, RED[1])
    finish(cv)
    tuft(cv, 4, 57)
    tuft(cv, 23, 57)
    return cv


def stone_lantern(lit: bool = True) -> Canvas:
    """Ishidōrō-style stone lantern with a warm glow."""
    cv = Canvas(38, 60)
    cv.shadow_blob(19, 56, 14, 3)
    # base
    cv.rect(9, 49, 29, 55, STONE[2])
    cv.rect(9, 49, 29, 50, STONE[1])
    cv.rect(26, 49, 29, 55, STONE[3])
    # post
    cv.rect(15, 34, 23, 49, STONE[1])
    cv.rect(15, 34, 16, 49, STONE[0])
    cv.rect(21, 34, 23, 49, STONE[2])
    # firebox platform
    cv.rect(8, 30, 30, 33, STONE[2])
    cv.rect(8, 30, 30, 30, STONE[1])
    # firebox
    cv.rect(11, 20, 27, 30, STONE[1])
    cv.rect(24, 20, 27, 30, STONE[2])
    glow = GLOW if lit else [hexc("5a5048"), hexc("4a4038"), hexc("3a3028")]
    cv.rect(15, 22, 23, 28, glow[1])
    cv.rect(16, 23, 22, 27, glow[0])
    cv.rect(19, 22, 19, 28, STONE[2])  # window mullion
    # roof
    cv.poly([(3, 20), (12, 12), (26, 12), (35, 20), (32, 21), (6, 21)], STONE[1])
    cv.replace_in(lambda x, y, c: c == STONE[1] and y <= 14, lambda x, y, c: STONE[0])
    cv.rect(6, 20, 32, 21, STONE[3])
    cv.set(3, 19, STONE[0]); cv.set(35, 19, STONE[0])
    # finial
    cv.ellipse(19, 9, 3, 3, STONE[1])
    cv.rect(18, 4, 20, 7, STONE[1])
    cv.set(19, 3, STONE[0])
    # moss patches
    for x, y in [(12, 13), (13, 13), (14, 12), (24, 13), (9, 31), (10, 31), (16, 45), (16, 46), (27, 50), (28, 50)]:
        cv.set(x, y, MOSS[1])
    finish(cv)
    if lit:
        for x, y in [(9, 24), (29, 24), (19, 17)]:
            cv.set(x, y, (255, 230, 150, 150))
    tuft(cv, 6, 57)
    tuft(cv, 32, 57)
    return cv


def birdhouse(knocked: bool) -> Canvas:
    """Birdhouse on a pole. Once knocked, a little bird sits on the roof."""
    cv = Canvas(30, 62)
    cv.shadow_blob(15, 58, 8, 2)
    cv.rect(14, 26, 16, 58, WOOD[2])
    cv.rect(14, 26, 14, 58, WOOD[1])
    # house
    cv.rect(7, 14, 23, 28, WOOD[1])
    cv.rect(7, 14, 9, 28, WOOD[0])
    cv.rect(21, 14, 23, 28, WOOD[2])
    for y in (18, 22, 26):
        cv.line(8, y, 22, y, WOOD[2])
    # roof
    cv.poly([(4, 15), (15, 5), (26, 15), (24, 16), (6, 16)], RED[2])
    cv.replace_in(lambda x, y, c: c == RED[2] and x < 15 and y < 14, lambda x, y, c: RED[1])
    cv.line(5, 15, 15, 5, RED[0])
    # hole + perch
    cv.ellipse(15, 20, 3, 3, hexc("24161a"))
    cv.rect(14, 25, 16, 25, DARKWOOD[1])
    finish(cv)
    if knocked:
        # bluebird on the roof peak
        cv.ellipse(18, 4, 3, 2.4, hexc("5a8fd6"))
        cv.ellipse(20, 2, 1.8, 1.8, hexc("5a8fd6"))
        cv.set(20, 2, hexc("1a1a22"))
        cv.set(22, 2, BRONZE[1])
        cv.set(17, 5, hexc("f2d6b0"))
        cv.set(15, 4, hexc("3c6aa8"))
    tuft(cv, 10, 59)
    tuft(cv, 20, 60)
    return cv


def persimmon_driver() -> Canvas:
    """Persimmon-headed driver lying in the grass."""
    cv = Canvas(46, 22)
    cv.shadow_blob(22, 17, 20, 3)
    # shaft diagonal
    cv.line(10, 14, 38, 5, METAL[1])
    cv.line(10, 15, 38, 6, METAL[2])
    # grip
    cv.line(35, 6, 43, 3, hexc("3a2a26"), 2)
    # head
    cv.ellipse(9, 14, 7, 5, DARKWOOD[1])
    cv.replace_in(lambda x, y, c: c == DARKWOOD[1] and y <= 11, lambda x, y, c: DARKWOOD[0])
    cv.replace_in(lambda x, y, c: c == DARKWOOD[1] and y >= 17, lambda x, y, c: DARKWOOD[2])
    cv.line(4, 15, 13, 18, hexc("e8d0a0"))  # face insert
    cv.set(7, 11, lighten(DARKWOOD[0], 0.5))
    cv.set(8, 11, lighten(DARKWOOD[0], 0.5))
    # whipping at hosel
    cv.rect(14, 12, 16, 13, hexc("1e1418"))
    finish(cv)
    tuft(cv, 25, 20)
    tuft(cv, 41, 12)
    return cv


def footbridge() -> Canvas:
    """Little arched wooden footbridge over a creek."""
    cv = Canvas(96, 44)
    # creek
    cv.ellipse(48, 36, 46, 7, WATER[2])
    cv.ellipse(48, 35, 42, 5, WATER[1])
    for x in range(10, 88, 7):
        cv.rect(x, 34 + (x % 3), x + 3, 34 + (x % 3), WATER[0])
    # banks
    cv.ellipse(6, 34, 8, 6, DIRT[1])
    cv.ellipse(90, 34, 8, 6, DIRT[1])
    # arch deck
    for x in range(4, 92):
        t = (x - 48) / 44.0
        y = int(round(26 - 14 * (1 - t * t)))
        cv.rect(x, y, x, y + 4, WOOD[1])
        cv.set(x, y, WOOD[0])
        cv.set(x, y + 4, WOOD[2])
        if x % 6 == 0:
            cv.rect(x, y + 1, x, y + 3, WOOD[2])
    # under-arch support
    for x in range(12, 85):
        t = (x - 48) / 36.0
        if abs(t) <= 1:
            y = int(round(34 - 12 * (1 - t * t)))
            cv.set(x, y, DARKWOOD[1])
            cv.set(x, y + 1, DARKWOOD[2])
    # railings
    for x in range(6, 91, 10):
        t = (x - 48) / 44.0
        y = int(round(26 - 14 * (1 - t * t)))
        cv.rect(x, y - 7, x + 1, y - 1, WOOD[1])
        cv.set(x, y - 7, WOOD[0])
    for x in range(6, 91):
        t = (x - 48) / 44.0
        y = int(round(26 - 14 * (1 - t * t))) - 7
        cv.set(x, y, WOOD[0])
        cv.set(x, y + 1, WOOD[2])
    finish(cv)
    tuft(cv, 2, 32)
    tuft(cv, 94, 32)
    return cv


def tee_sign() -> Canvas:
    """Carved wooden sign: HOLE 1 · PAR 4 · 385 YDS."""
    cv = Canvas(58, 56)
    cv.shadow_blob(29, 52, 22, 3)
    for x in (12, 43):
        cv.rect(x, 26, x + 2, 52, WOOD[2])
        cv.rect(x, 26, x, 52, WOOD[1])
    # board
    cv.rect(3, 4, 54, 30, WOOD[1])
    cv.rect(3, 4, 54, 5, WOOD[0])
    cv.rect(3, 29, 54, 30, WOOD[3])
    cv.rect(52, 4, 54, 30, WOOD[2])
    for y in (12, 21):
        cv.line(4, y, 53, y, WOOD[2])
    # carved text
    carve = hexc("f7e3b6")
    lit = hexc("4a2c16")
    for row, s in enumerate(["HOLE 1", "PAR 4", "385 YDS"]):
        w = text_width(s)
        text(cv, 29 - w // 2, 7 + row * 8, s, carve, shadow=lit)
    # little flag painted on the corner
    cv.rect(47, 7, 47, 11, METAL[3])
    cv.rect(48, 7, 50, 9, RED[1])
    finish(cv)
    tuft(cv, 9, 53)
    tuft(cv, 47, 54)
    tuft(cv, 28, 55, 2)
    return cv


def green_disc() -> Canvas:
    """Flat putting-green disc (laid on the ground, not billboarded)."""
    size = 96
    cv = Canvas(size, size)
    c = size / 2
    cv.ellipse(c, c, 46, 46, hexc("3f8a2f"))  # fringe
    cv.ellipse(c, c, 42, 42, hexc("6cc04a"))
    # mowing rings
    for r in range(8, 42, 8):
        for a in range(0, 360, 2):
            import math
            x = int(c + r * math.cos(math.radians(a)))
            y = int(c + r * math.sin(math.radians(a)))
            if cv.get(x, y) == hexc("6cc04a"):
                cv.set(x, y, hexc("78cc55"))
    # cup
    cv.ellipse(c, c, 3, 3, hexc("1e1418"))
    cv.ellipse(c, c - 1, 2, 1.2, hexc("40302a"))
    return cv


def flagstick(with_cap: bool = True) -> Canvas:
    """Flagstick with a red flag and Barley's cap hung on it."""
    cv = Canvas(34, 70)
    cv.rect(10, 4, 11, 66, WHITE[1])
    cv.rect(10, 4, 10, 66, WHITE[0])
    for y in range(8, 66, 8):
        cv.rect(10, y, 11, y + 3, RED[1])
    # flag with a gentle wave
    for x in range(12, 31):
        wave = int(round(1.5 * __import__("math").sin((x - 12) / 3.0)))
        top = 4 + wave
        bot = 18 - (x - 12) // 3 + wave
        cv.rect(x, top, x, bot, RED[1])
        cv.set(x, top, RED[0])
        cv.set(x, bot, RED[2])
    text(cv, 19, 8, "1", WHITE[0])
    cv.rect(8, 3, 13, 3, METAL[2])
    if with_cap:
        # green cap hanging off the stick at mid-height
        cv.ellipse(7, 33, 6, 4, CAP_GREEN[1])
        cv.replace_in(lambda x, y, c: c == CAP_GREEN[1] and y <= 31, lambda x, y, c: CAP_GREEN[0])
        cv.rect(1, 35, 14, 36, CAP_GREEN[2])  # brim
        cv.set(7, 30, WHITE[0])  # button
        cv.rect(5, 33, 9, 33, WHITE[1])  # stripe
    finish(cv)
    return cv


def sparkle() -> Canvas:
    cv = Canvas(9, 9)
    col = hexc("fff6c2")
    for i in range(9):
        a = 255 if abs(i - 4) <= 1 else 150
        cv.set(4, i, (col[0], col[1], col[2], a))
        cv.set(i, 4, (col[0], col[1], col[2], a))
    cv.set(4, 4, hexc("ffffff"))
    return cv


def journal_icon() -> Canvas:
    """Small leather notebook with a pencil (HUD button glyph)."""
    cv = Canvas(18, 18)
    cv.rect(3, 2, 14, 15, hexc("8a4b2e"))
    cv.rect(3, 2, 4, 15, hexc("5a2e1c"))
    cv.rect(5, 3, 13, 14, hexc("a8603a"))
    cv.rect(6, 5, 12, 6, PAPER[1])
    cv.rect(13, 8, 15, 9, RED[1])  # bookmark ribbon
    cv.line(10, 10, 14, 14, hexc("e8b64a"))
    cv.set(15, 15, hexc("3a2a26"))
    cv.outline(OUTLINE)
    return cv


SPRITES = {
    "scorecard": scorecard,
    "ratina_bag": ratina_bag,
    "range_bell": lambda: range_bell(False),
    "range_bell_rung": lambda: range_bell(True),
    "picker_cart": picker_cart,
    "rattling_burrow": rattling_burrow,
    "barley_spoon": barley_spoon,
    "stone_lantern": stone_lantern,
    "birdhouse": lambda: birdhouse(False),
    "birdhouse_knocked": lambda: birdhouse(True),
    "persimmon_driver": persimmon_driver,
    "footbridge": footbridge,
    "tee_sign": tee_sign,
    "green_disc": green_disc,
    "flagstick": flagstick,
    "sparkle": sparkle,
    "journal_icon": journal_icon,
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    made = {}
    for name, fn in SPRITES.items():
        cv = fn()
        cv.save(os.path.join(OUT, name + ".png"))
        made[name] = cv
    if "--preview" in sys.argv:
        from PIL import Image

        out = sys.argv[sys.argv.index("--preview") + 1]
        scale = 4
        pad = 8
        ims = [cv.image(scale) for cv in made.values()]
        row_w = 1100
        x = y = 0
        row_h = 0
        placed = []
        for im in ims:
            if x + im.width > row_w:
                x = 0
                y += row_h + pad
                row_h = 0
            placed.append((im, x, y))
            x += im.width + pad
            row_h = max(row_h, im.height)
        sheet = Image.new("RGBA", (row_w, y + row_h), (86, 150, 64, 255))
        for im, px, py in placed:
            sheet.alpha_composite(im, (px, py))
        sheet.save(out)
    print("wrote", len(made), "sprites to", OUT)


if __name__ == "__main__":
    main()
