#!/usr/bin/env python3
"""Sword-pickup vignette pack: pedestal, window icon, glint particle.

Deterministic. Outputs (RGBA):
  pedestal.png   24x16  low weathered stone altar (bottom-anchored)
  icon.png       128x128 window icon: gold-bordered badge + diagonal sword
  glint_star.png 7x7    4-point pickup sparkle (softer little spark)

Previews -> /tmp/pickup_preview_{grass,dark}.png (4x sheet),
            /tmp/pickup_detail.png (big zooms incl. icon@32 readback).
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def hx(s, a=255):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# master palette
K = hx('1a140f')
STONE = [hx('55554f'), hx('6b6b66'), hx('8d8d85'), hx('b0afa3')]
GOLD_D, GOLD_M = hx('4a3a1c'), hx('8a6d2f')
GOLD, GOLD_L = hx('d4a843'), hx('f0d27a')
FILL = hx('14100c')
GRASS_LT, GRASS_HI = hx('4f8f4f'), hx('6fae5a')
WHITE = hx('ffffff')


# ---------------------------------------------------------------- helpers
def render(px, w, h):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for (x, y), c in px.items():
        if 0 <= x < w and 0 <= y < h:
            img.putpixel((x, y), c)
    return img


def outline(px, w, h):
    """1px outline inside silhouette; skip pure bottom edges near ground."""
    solid = set(px.keys())
    edge = []
    for (x, y) in solid:
        dirs = []
        for dx, dy, name in ((0, -1, 'u'), (0, 1, 'd'), (-1, 0, 'l'), (1, 0, 'r')):
            n = (x + dx, y + dy)
            if n not in solid:
                if 0 <= n[0] < w and 0 <= n[1] < h:
                    dirs.append(name)
                elif name != 'd':
                    dirs.append(name)
        if not dirs:
            continue
        if dirs == ['d'] and y >= h - 3:
            continue
        edge.append((x, y))
    for p in edge:
        px[p] = K


# ---------------------------------------------------------------- pedestal
def gen_pedestal():
    """Low weathered plinth: lit top slab, shadowed waist, flared base.
    Deliberately squat (content rows 7-14) so a hero standing behind it
    is hidden no higher than the shins."""
    w, h = 24, 16
    px = {}
    # silhouette masks per tier (top slab / waist / base plinth)
    slab = {(x, y) for y in range(7, 12) for x in range(3, 21)}
    waist = {(x, y) for y in range(12, 13) for x in range(5, 19)}
    base = {(x, y) for y in range(13, 15) for x in range(3, 21)}
    # weathering: chip corners off the slab and base
    chips = {(20, 7), (19, 7), (20, 8), (3, 7), (3, 11), (20, 13)}
    mask = (slab | waist | base) - chips
    for (x, y) in mask:
        if y <= 9:                       # flat top face (lit)
            c = STONE[2] if (y == 9 and x >= 12) or x >= 18 else STONE[3]
        elif y <= 11:                    # slab front lip
            c = STONE[0] if x >= 18 else STONE[1]
        elif y == 12:                    # shadow under the slab overhang
            c = STONE[0]
        else:                            # base plinth
            if y == 13 and x <= 6:
                c = STONE[2]
            elif x >= 18 or y == 14:
                c = STONE[0]
            else:
                c = STONE[1]
        px[(x, y)] = c
    # cracks: one down the lip (forked), one nicking the slab edge
    for (x, y) in ((9, 9), (9, 10), (10, 10), (10, 11)):
        px[(x, y)] = STONE[0]
    px[(9, 11)] = hx('3f3f3a')          # deepest point of the crack
    for (x, y) in ((14, 8), (15, 12), (16, 13)):
        px[(x, y)] = STONE[0]
    # small chisel highlight on the lip (top-left light)
    px[(5, 10)] = STONE[2]
    px[(6, 10)] = STONE[2]
    outline(px, w, h)
    # grass tufts at the base (after outline so they sit on top)
    for (x, y) in ((1, 13), (20, 14), (10, 14)):
        px[(x, y)] = GRASS_LT
        px[(x + 1, y)] = GRASS_LT
        px[(x, y - 1)] = GRASS_HI
    return render(px, w, h)


# ---------------------------------------------------------------- icon
def _badge32():
    """ui_panel ring language at 32x32 (scaled 4x -> 128 badge)."""
    S = 32
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
                    c = GOLD_L
                elif (bottom or right) and not (top or left):
                    c = GOLD_M
                else:
                    c = GOLD
            elif ring == 2:
                c = GOLD
            elif ring == 3:
                c = GOLD_D
            else:
                c = FILL
            px[x, y] = c
    # stepped corner chamfer (same cut as ui_panel)
    corners = [
        (lambda x, y: (x, y), GOLD_L),
        (lambda x, y: (S - 1 - x, y), GOLD),
        (lambda x, y: (x, S - 1 - y), GOLD),
        (lambda x, y: (S - 1 - x, S - 1 - y), GOLD_M),
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


def gen_icon():
    badge = _badge32().resize((128, 128), Image.NEAREST)
    # sword from sword_clean.png, rotated to point up-right, 3x integer scale
    sw = Image.open(os.path.join(HERE, 'sword_clean.png')).convert('RGBA')
    sw = sw.crop(sw.getbbox())
    rot = sw.rotate(-45, resample=Image.NEAREST, expand=True)
    rot = rot.crop(rot.getbbox())
    rot = rot.resize((rot.width * 3, rot.height * 3), Image.NEAREST)
    ox = (128 - rot.width) // 2 - 2
    oy = (128 - rot.height) // 2 + 2
    # blade tip = opaque pixel maximizing (x - y)  (up-right corner)
    tip, best = None, None
    rp = rot.load()
    for y in range(rot.height):
        for x in range(rot.width):
            if rp[x, y][3] > 0:
                s = x - y
                if best is None or s > best:
                    best, tip = s, (x, y)
    tx, ty = ox + tip[0], oy + tip[1]
    # warm glow behind the tip: chunky 4px blocks, diamond falloff
    bp = badge.load()

    def block(bx, by, c):
        for dx in range(4):
            for dy in range(4):
                X, Y = bx * 4 + dx, by * 4 + dy
                if 0 <= X < 128 and 0 <= Y < 128 and bp[X, Y] == FILL:
                    bp[X, Y] = c
    gx, gy = tx // 4, ty // 4               # glow sits behind the tip itself
    for dbx in range(-2, 3):
        for dby in range(-2, 3):
            d = abs(dbx) + abs(dby)
            if d == 0:
                block(gx, gy, GOLD_L)
            elif d == 1:
                block(gx + dbx, gy + dby, GOLD)
            elif d == 2 and dbx != 0 and dby != 0:
                continue                      # keep the diamond pointy
            elif d == 2:
                block(gx + dbx, gy + dby, GOLD_D)
    block(gx + 2, gy - 2, GOLD_L)            # detached twinkle past the point
    block(gx + 3, gy - 1, GOLD_D)
    badge.alpha_composite(rot, (ox, oy))
    return badge


# ---------------------------------------------------------------- glint star
def gen_glint_star():
    """7x7 sparkle: white core, #f0d27a tips, soft diagonal corners."""
    im = Image.new('RGBA', (7, 7), (0, 0, 0, 0))
    px = im.load()
    c = 3
    for i in range(4):
        col = WHITE if i <= 1 else GOLD_L
        px[c + i, c] = col
        px[c - i, c] = col
        px[c, c + i] = col
        px[c, c - i] = col
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        px[c + dx, c + dy] = hx('f0d27a', 90)
    return im


# ---------------------------------------------------------------- validate
def validate(name, img, binary=True, bottom=None):
    w, h = img.size
    if bottom is not None:
        lowest = max(y for y in range(h)
                     if any(img.getpixel((x, y))[3] > 0 for x in range(w)))
        margin = h - 1 - lowest
        assert margin <= bottom, f'{name}: bottom margin {margin}px'
    if binary:
        for y in range(h):
            for x in range(w):
                a = img.getpixel((x, y))[3]
                assert a in (0, 255), f'{name}: semi-alpha at {x},{y}'


# ---------------------------------------------------------------- previews
def build_previews(ped, icon, glint):
    sword = Image.open(os.path.join(HERE, 'sword_clean.png')).convert('RGBA')
    icon32 = icon.resize((32, 32), Image.NEAREST)
    for tag, bgc in (('grass', hx('4a7a38')), ('dark', hx('14100c'))):
        sheet = Image.new('RGBA', (266, 144), bgc)
        sheet.alpha_composite(ped, (8, 120))                 # pedestal alone
        sheet.alpha_composite(ped, (44, 120))                # + resting sword
        sheet.alpha_composite(sword, (40, 92))
        sheet.alpha_composite(glint, (84, 126))
        sheet.alpha_composite(icon, (100, 8))
        sheet.alpha_composite(icon32, (236, 8))              # 32x32 readback
        sheet = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
        sheet.save('/tmp/pickup_preview_%s.png' % tag)
    # detail zooms: pedestal 10x, glint 16x, icon@32 shown 6x
    n = Image.NEAREST
    z = Image.new('RGBA', (560, 240), hx('4a7a38'))
    z.alpha_composite(ped.resize((240, 160), n), (8, 50))
    z.alpha_composite(glint.resize((112, 112), n), (260, 60))
    z.alpha_composite(icon32.resize((192, 192), n), (384, 24))
    z.save('/tmp/pickup_detail.png')


def main():
    ped = gen_pedestal()
    icon = gen_icon()
    glint = gen_glint_star()
    validate('pedestal', ped, bottom=2)
    validate('icon', icon)
    validate('glint_star', glint, binary=False)
    ped.save(os.path.join(HERE, 'pedestal.png'))
    icon.save(os.path.join(HERE, 'icon.png'))
    glint.save(os.path.join(HERE, 'glint_star.png'))
    for nm, im in (('pedestal', ped), ('icon', icon), ('glint_star', glint)):
        print('wrote', nm + '.png', im.size)
    build_previews(ped, icon, glint)
    print('previews -> /tmp/pickup_preview_{grass,dark}.png /tmp/pickup_detail.png')


if __name__ == '__main__':
    main()
