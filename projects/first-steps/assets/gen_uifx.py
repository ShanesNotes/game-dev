#!/usr/bin/env python3
"""UI chrome + VFX texture pack for first-steps.

Deterministic generator (fixed seed). Outputs:
  ui_panel.png 48x48, ui_bar_bg.png 64x12, ui_bar_fill_hp.png 64x12,
  ui_bar_fill_rage.png 64x12, vignette.png 480x270, slash_arc.png 48x48,
  spark.png 9x9, soft_dot.png 8x8, aggro_mark.png 10x14
Also builds /tmp previews (dark + grass backgrounds, NEAREST upscale).
"""
import math
import os
import random

from PIL import Image

random.seed(20260611)
HERE = os.path.dirname(os.path.abspath(__file__))


def hx(s, a=255):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# master palette
K = hx('1a140f')                      # universal outline
GOLD_D, GOLD_M = hx('4a3a1c'), hx('8a6d2f')
GOLD, GOLD_L = hx('d4a843'), hx('f0d27a')
PANEL_FILL = hx('14100c', 235)
TROUGH = hx('14100c')
HP, HP_L, HP_D = hx('2fbf4a'), hx('5fdf78'), hx('1a7a2e')
RAGE, RAGE_L, RAGE_D = hx('c92f24'), hx('e85a4a'), hx('7a1c14')
RED_SHADE = hx('8a1f16')
WHITE, OFFWHITE = hx('ffffff'), hx('e0e6ef')

BAYER8 = [
    [0, 32, 8, 40, 2, 34, 10, 42],
    [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41],
    [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37],
    [63, 31, 55, 23, 61, 29, 53, 21],
]


# ---------------------------------------------------------------- ui_panel
def gen_panel():
    S = 48
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    px = im.load()
    for y in range(S):
        for x in range(S):
            ring = min(x, y, S - 1 - x, S - 1 - y)
            if ring == 0:
                c = K
            elif ring == 1:
                top, left = y == 1, x == 1
                bottom, right = y == S - 2, x == S - 2
                if (top or left) and not (bottom or right):
                    c = GOLD_L           # lit bevel (top-left light)
                elif (bottom or right) and not (top or left):
                    c = GOLD_M           # shaded bevel
                else:
                    c = GOLD             # mixed corners (tr / bl)
            elif ring == 2:
                c = GOLD
            elif ring == 3:
                c = GOLD_D
            else:
                c = PANEL_FILL
            px[x, y] = c

    # 3px stepped chamfer on each corner silhouette
    corners = [
        (lambda x, y: (x, y), GOLD_L),               # tl
        (lambda x, y: (S - 1 - x, y), GOLD),         # tr
        (lambda x, y: (x, S - 1 - y), GOLD),         # bl
        (lambda x, y: (S - 1 - x, S - 1 - y), GOLD_M),  # br
    ]
    for f, bev in corners:
        for x in range(6):
            for y in range(6):
                d = x + y
                X, Y = f(x, y)
                if d < 3:
                    px[X, Y] = (0, 0, 0, 0)
                elif d == 3:
                    px[X, Y] = K
                elif d == 4 and x >= 1 and y >= 1:
                    px[X, Y] = bev
    return im


# ---------------------------------------------------------------- bars
def gen_bar_bg():
    W, H = 64, 12
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            if x in (0, W - 1) or y in (0, H - 1):
                px[x, y] = K
            else:
                px[x, y] = TROUGH
    for x in range(1, W - 1):          # inner top shadow (recessed look)
        px[x, 1] = hx('080604')
    return im


def gen_bar_fill(base, light, dark):
    W, H = 64, 12
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if y <= 3:
                c = light                # lighter top third
            elif y == H - 2:
                c = dark                 # dark bottom line
            else:
                c = base
            px[x, y] = c
    return im


# ---------------------------------------------------------------- vignette
def gen_vignette():
    W, H = 480, 270
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
    inv = 1.0 / math.sqrt(2.0)
    for y in range(H):
        row = BAYER8[y % 8]
        for x in range(W):
            dx, dy = (x - cx) / cx, (y - cy) / cy
            rn = math.sqrt(dx * dx + dy * dy) * inv   # corner == 1.0
            t = (rn - 0.55) / 0.45
            if t <= 0.0:
                continue
            t = min(t, 1.0)
            s = t * t * (3.0 - 2.0 * t)               # smoothstep
            af = 150.0 * s
            a = int(af)
            if (af - a) * 64.0 > row[x % 8] + 0.5:    # ordered dither
                a += 1
            if a > 0:
                px[x, y] = (0, 0, 0, a)
    return im


# ---------------------------------------------------------------- slash arc
def _q(a):
    """quantize alpha into chunky steps; kill faint AA fringe"""
    if a < 40:
        return 0
    for lv in (60, 110, 160, 210, 255):
        if a <= lv + 25:
            return lv
    return 255


def gen_slash():
    S = 48
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    px = im.load()
    cx, cy, R = 14.0, 34.0, 24.0
    a0, a1 = math.radians(-25.0), math.radians(95.0)   # 120 deg sweep
    cap = math.radians(14.0)                           # rounded head cap
    for y in range(S):
        for x in range(S):
            ddx, ddy = x - cx, -(y - cy)
            ang = math.atan2(ddy, ddx)
            if not (a0 <= ang <= a1 + cap):
                continue
            if ang > a1:                               # taper the head tip
                u = (ang - a1) / cap
                t = 1.0
                w = 5.0 * (1.0 - u) ** 1.5
                if w < 1.0:
                    continue
            else:
                t = (ang - a0) / (a1 - a0)             # 0 tail -> 1 head
                w = 1.0 + 4.0 * t                      # thin tail -> 5px head
            dist = math.hypot(ddx, ddy)
            d = dist - R
            if abs(d) <= w * 0.5:
                # solid white for leading 45%, stepped falloff down the tail
                af = 255.0 if t > 0.55 else 255.0 * (t / 0.55) ** 0.7
                a = _q(af)
                if a:
                    px[x, y] = (255, 255, 255, a)
            elif t > 0.35 and -(w * 0.5 + 2.0) <= d < -(w * 0.5):
                px[x, y] = (255, 255, 255, 60)         # inner glow band
    return im


# ---------------------------------------------------------------- spark
def gen_spark():
    im = Image.new('RGBA', (9, 9), (0, 0, 0, 0))
    px = im.load()
    c = 4
    for i in range(5):
        col = WHITE if i <= 2 else GOLD_L
        px[c + i, c] = col
        px[c - i, c] = col
        px[c, c + i] = col
        px[c, c - i] = col
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        px[c + dx, c + dy] = (255, 255, 255, 130)
    return im


# ---------------------------------------------------------------- soft dot
def gen_soft_dot():
    im = Image.new('RGBA', (8, 8), (0, 0, 0, 0))
    px = im.load()
    cc = 3.5
    for y in range(8):
        for x in range(8):
            d = math.hypot(x - cc, y - cc) / 4.0
            if d >= 1.0:
                continue
            a = int(200.0 * (1.0 - d * d) ** 1.3 / 15) * 15
            if a > 0:
                px[x, y] = (255, 255, 255, a)
    return im


# ---------------------------------------------------------------- aggro mark
AGGRO_MAP = [
    "..KKKKKK..",
    "..KWRRDK..",
    "..KLRRDK..",
    "..KRRRDK..",
    "..KRRRDK..",
    "...KRRDK..",
    "...KRRDK..",
    "...KRDK...",
    "....KK....",
    "..........",
    "...KKKK...",
    "..KWRRDK..",
    "..KRRDDK..",
    "...KKKK...",
]
AGGRO_INK = {'K': K, 'R': RAGE, 'D': RED_SHADE, 'W': OFFWHITE, 'L': RAGE_L}


def gen_aggro():
    im = Image.new('RGBA', (10, 14), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(AGGRO_MAP):
        for x, ch in enumerate(row):
            if ch != '.':
                px[x, y] = AGGRO_INK[ch]
    return im


# ---------------------------------------------------------------- previews
def nine_slice(src, w, h, m=10):
    S = src.size[0]
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    n = Image.NEAREST
    out.paste(src.crop((0, 0, m, m)), (0, 0))
    out.paste(src.crop((S - m, 0, S, m)), (w - m, 0))
    out.paste(src.crop((0, S - m, m, S)), (0, h - m))
    out.paste(src.crop((S - m, S - m, S, S)), (w - m, h - m))
    out.paste(src.crop((m, 0, S - m, m)).resize((w - 2 * m, m), n), (m, 0))
    out.paste(src.crop((m, S - m, S - m, S)).resize((w - 2 * m, m), n), (m, h - m))
    out.paste(src.crop((0, m, m, S - m)).resize((m, h - 2 * m), n), (0, m))
    out.paste(src.crop((S - m, m, S, S - m)).resize((m, h - 2 * m), n), (w - m, m))
    out.paste(src.crop((m, m, S - m, S - m)).resize((w - 2 * m, h - 2 * m), n), (m, m))
    return out


def bar_with_fill(bg, fill, pct):
    out = bg.copy()
    if pct > 0:
        wpx = 1 + int(62 * pct)
        out.alpha_composite(fill.crop((0, 0, wpx, 12)), (0, 0))
    return out


def build_previews(sp):
    for tag, bgc in (('dark', hx('14100c')), ('grass', hx('3b7242'))):
        sheet = Image.new('RGBA', (250, 152), bgc)
        sheet.alpha_composite(sp['panel'], (6, 6))
        sheet.alpha_composite(nine_slice(sp['panel'], 120, 64), (62, 6))
        sheet.alpha_composite(sp['slash'], (192, 6))
        bb, fh, fr = sp['bar_bg'], sp['hp'], sp['rage']
        sheet.alpha_composite(bb, (6, 84))
        sheet.alpha_composite(bar_with_fill(bb, fh, 1.0), (76, 84))
        sheet.alpha_composite(bar_with_fill(bb, fh, 0.6), (146, 84))
        sheet.alpha_composite(bar_with_fill(bb, fr, 1.0), (6, 102))
        sheet.alpha_composite(bar_with_fill(bb, fr, 0.35), (76, 102))
        sheet.alpha_composite(sp['spark'], (152, 104))
        sheet.alpha_composite(sp['soft_dot'], (170, 105))
        sheet.alpha_composite(sp['aggro'], (188, 100))
        sheet = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
        sheet.save('/tmp/uifx_preview_%s.png' % tag)

    # vignette over flat green frame, 1x, plus 3x corner crop for banding check
    green = Image.new('RGBA', (480, 270), hx('3b7242'))
    green.alpha_composite(sp['vignette'])
    green.save('/tmp/uifx_vignette_green.png')
    crop = green.crop((0, 0, 150, 150)).resize((450, 450), Image.NEAREST)
    crop.save('/tmp/uifx_vignette_corner3x.png')

    # zoom strips: panel corners 8x, small sprites 8x, slash 6x
    n = Image.NEAREST
    for tag, bgc in (('dark', hx('14100c')), ('grass', hx('3b7242'))):
        z = Image.new('RGBA', (850, 304), bgc)
        z.alpha_composite(sp['panel'].crop((0, 0, 16, 16)).resize((128, 128), n), (8, 8))
        z.alpha_composite(sp['panel'].crop((32, 32, 48, 48)).resize((128, 128), n), (8, 160))
        z.alpha_composite(sp['aggro'].resize((80, 112), n), (170, 8))
        z.alpha_composite(sp['spark'].resize((72, 72), n), (170, 150))
        z.alpha_composite(sp['soft_dot'].resize((64, 64), n), (175, 232))
        z.alpha_composite(sp['slash'].resize((288, 288), n), (280, 8))
        z.alpha_composite(sp['bar_bg'].resize((256, 48), n), (584, 30))
        z.alpha_composite(bar_with_fill(sp['bar_bg'], sp['hp'], 0.65).resize((256, 48), n), (584, 100))
        z.alpha_composite(bar_with_fill(sp['bar_bg'], sp['rage'], 0.65).resize((256, 48), n), (584, 170))
        z.save('/tmp/uifx_zoom_%s.png' % tag)


def main():
    sp = {
        'panel': gen_panel(),
        'bar_bg': gen_bar_bg(),
        'hp': gen_bar_fill(HP, HP_L, HP_D),
        'rage': gen_bar_fill(RAGE, RAGE_L, RAGE_D),
        'vignette': gen_vignette(),
        'slash': gen_slash(),
        'spark': gen_spark(),
        'soft_dot': gen_soft_dot(),
        'aggro': gen_aggro(),
    }
    names = {
        'panel': 'ui_panel.png', 'bar_bg': 'ui_bar_bg.png',
        'hp': 'ui_bar_fill_hp.png', 'rage': 'ui_bar_fill_rage.png',
        'vignette': 'vignette.png', 'slash': 'slash_arc.png',
        'spark': 'spark.png', 'soft_dot': 'soft_dot.png',
        'aggro': 'aggro_mark.png',
    }
    for k, fn in names.items():
        sp[k].save(os.path.join(HERE, fn))
        print('wrote', fn, sp[k].size)
    build_previews(sp)
    print('previews -> /tmp/uifx_preview_{dark,grass}.png, /tmp/uifx_vignette_*.png')


if __name__ == '__main__':
    main()
