#!/usr/bin/env python3
"""Deterministic vegetation & props pack generator (16-bit style).

Outputs (all RGBA, transparent bg, ground anchor = bottom-center):
  tree_oak_a.png 48x64, tree_oak_b.png 48x64, tree_pine.png 40x72,
  bush_a.png 24x18, bush_b.png 20x16, rock_a.png 18x12, rock_b.png 26x16,
  stump.png 20x16, mushroom_cluster.png 14x12

Also writes a /tmp/props_preview.png (grass + gray panels, 5x nearest).
"""
import random
from PIL import Image

random.seed(20260611)

OUT = "/home/ark/game-dev/projects/first-steps/assets"


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


OUTLINE = C("1a140f")

# foliage ramp (dark -> light)
FOL = [C("1e4527"), C("2e6634"), C("3f8743"), C("5cab51")]
GLINT = C("7fcf6a")

WOOD = [C("3a2817"), C("4a3320"), C("6b4a2b"), C("8a653c")]
STONE = [C("55554f"), C("6b6b66"), C("8d8d85"), C("b0afa3")]
GRASS_LT = C("4f8f4f")
GRASS_HI = C("6fae5a")
RED = C("c14b3a")
WHITE = C("e0e6ef")


# ---------------------------------------------------------------- helpers
def render(px, w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for (x, y), c in px.items():
        if 0 <= x < w and 0 <= y < h:
            img.putpixel((x, y), c)
    return img


def outline(px, w, h):
    """1px outline inside silhouette; skip pure bottom-facing edges near ground."""
    solid = set(px.keys())
    edge = []
    for (x, y) in solid:
        dirs = []
        for dx, dy, name in ((0, -1, "u"), (0, 1, "d"), (-1, 0, "l"), (1, 0, "r")):
            n = (x + dx, y + dy)
            if n not in solid:
                if 0 <= n[0] < w and 0 <= n[1] < h:
                    dirs.append(name)
                elif name != "d":
                    dirs.append(name)
                else:
                    # below canvas == ground contact, never outline-trigger
                    pass
        if not dirs:
            continue
        # skip outline where the only exposure is downward near the ground line
        if dirs == ["d"] and y >= h - 3:
            continue
        edge.append((x, y))
    for p in edge:
        px[p] = OUTLINE


def blob_mask(blobs, w, h):
    """Union of ellipses. Returns (mask:set, owner:dict pixel->blob), later blobs on top."""
    mask, owner = set(), {}
    for b in blobs:
        cx, cy, rx, ry = b
        for y in range(max(0, int(cy - ry)), min(h, int(cy + ry) + 1)):
            for x in range(max(0, int(cx - rx)), min(w, int(cx + rx) + 1)):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    mask.add((x, y))
                    owner[(x, y)] = b
    return mask, owner


def shade_foliage(px, blobs, w, h, glint_count=4, ramp=FOL,
                  th=(-0.45, 0.10, 0.80), under=2):
    """Cloud-style per-blob shading, quantized to 2x2 blocks. Light = top-left."""
    mask, owner = blob_mask(blobs, w, h)
    # smooth silhouette: drop 1px spurs (they become ugly outline nubs)
    for _ in range(2):
        spurs = {p for p in mask
                 if sum(((p[0] + dx, p[1] + dy) in mask)
                        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0))) < 2}
        if not spurs:
            break
        mask -= spurs
    light_blocks = []
    for (x, y) in mask:
        cx, cy, rx, ry = owner[(x, y)]
        bx = (x // 2) * 2 + 1.0
        by = (y // 2) * 2 + 1.0
        t = ((bx - cx) / rx) * 0.7 + ((by - cy) / ry) * 1.1
        # union-mask underside -> deepest tone
        below = all((x, y + d) not in mask for d in range(1, under + 1))
        if below:
            tone = 0
        elif t < th[0]:
            tone = 3
        elif t < th[1]:
            tone = 2
        elif t < th[2]:
            tone = 1
        else:
            tone = 0
        px[(x, y)] = ramp[tone]
        if tone == 3 and x % 2 == 0 and y % 2 == 0:
            if bx < w * 0.60 and by < h * 0.50:
                light_blocks.append((x, y))
    light_blocks.sort()
    picks = random.sample(light_blocks, min(glint_count, len(light_blocks)))
    for (x, y) in picks:
        for dx in range(2):
            for dy in range(2):
                if (x + dx, y + dy) in mask:
                    px[(x + dx, y + dy)] = GLINT
    return mask


def trunk(px, cx, y0, y1, half, flare_rows=3):
    """Vertical trunk, left-lit; root flares widen the bottom rows."""
    for y in range(y0, y1 + 1):
        extra = 0
        rows_from_bottom = y1 - y
        if rows_from_bottom < flare_rows:
            extra = flare_rows - rows_from_bottom - 1
        x0, x1 = cx - half - extra, cx + half + extra
        for x in range(x0, x1 + 1):
            if x == x0:
                c = WOOD[3]          # lit left edge
            elif x >= x1 - 1:
                c = WOOD[1]          # shadow right
            else:
                c = WOOD[2]          # base
            # don't overwrite canopy foliage
            if (x, y) not in px:
                px[(x, y)] = c


# ---------------------------------------------------------------- sprites
def tree_oak_a():
    w, h = 48, 64
    px = {}
    trunk(px, 24, 30, 62, 3, flare_rows=4)
    blobs = [
        (24, 22, 21, 16),   # main mass
        (10, 27, 8, 8),     # left lobe
        (39, 26, 8, 8),     # right lobe
        (33, 12, 11, 9),    # upper-right
        (13, 14, 10, 9),    # upper-left
        (23, 8, 9, 7),      # crown
        (27, 31, 11, 8),    # lower-front
    ]
    shade_foliage(px, blobs, w, h, glint_count=4)
    outline(px, w, h)
    return render(px, w, h)


def tree_oak_b():
    w, h = 48, 64
    px = {}
    trunk(px, 25, 30, 62, 3, flare_rows=4)
    blobs = [
        (24, 24, 22, 14),   # wide flat mass
        (8, 19, 8, 9),      # big left lobe
        (15, 11, 10, 8),    # upper-left crown
        (31, 9, 9, 8),      # upper-right bump
        (40, 20, 7, 8),     # right lobe (smaller, notch under it)
        (28, 30, 12, 8),    # lower-front
        (36, 31, 7, 6),     # low right tuft
    ]
    shade_foliage(px, blobs, w, h, glint_count=4)
    outline(px, w, h)
    return render(px, w, h)


def tree_pine():
    w, h = 40, 72
    px = {}
    cx = 20
    # trunk first (fronds draw over it)
    for y in range(52, 71):
        extra = 1 if y >= 69 else 0
        for x in range(cx - 2 - extra, cx + 2 + extra):
            if x == cx - 2 - extra:
                c = WOOD[3]
            elif x >= cx + 1:
                c = WOOD[1]
            else:
                c = WOOD[2]
            px[(x, y)] = c
    # tiers: (y_top, y_bot, hw_top, hw_bot) -- draw bottom tier first,
    # upper tiers overwrite, so each exposed underside band survives.
    tiers = [(2, 15, 1, 8), (10, 28, 2, 12), (20, 42, 3, 15), (32, 56, 4, 18)]
    for (yt, yb, hwt, hwb) in reversed(tiers):
        for y in range(yt, yb + 1):
            f = (y - yt) / (yb - yt)
            hw = hwt + (hwb - hwt) * f
            jitter = [0, 1, 1, 0][(y // 2) % 4]
            hw = max(1, int(hw + jitter))
            hw = min(hw, y - yt + 1)      # pointy apex on each tier
            xl, xr = cx - hw, cx + hw
            for x in range(xl, xr + 1):
                if y >= yb - 1:
                    c = FOL[0]                    # tier underside shadow
                elif x <= xl + 2 and y < yb - 3:
                    c = FOL[2]                    # lit left edge
                elif x >= xr - 1:
                    c = FOL[0]                    # shaded right rim
                else:
                    c = FOL[1]
                px[(x, y)] = c
    # glints on upper-left edges (2px runs)
    for (yt, yb, hwt, hwb) in tiers[:3]:
        gy = yt + (yb - yt) // 3
        ghw = hwt + (hwb - hwt) * ((gy - yt) / (yb - yt))
        gx = cx - int(ghw)
        for d in range(2):
            if (gx + d, gy) in px:
                px[(gx + d, gy)] = FOL[3]
    outline(px, w, h)
    return render(px, w, h)


def bush(w, h, blobs, berries):
    px = {}
    shade_foliage(px, blobs, w, h, glint_count=2,
                  th=(-0.30, 0.45, 1.60), under=1)
    outline(px, w, h)
    for (x, y) in berries:
        px[(x, y)] = RED
    return render(px, w, h)


def bush_a():
    blobs = [(12, 11, 10, 6), (7, 9, 6, 5), (17, 9, 6, 5), (12, 7, 5, 4)]
    # berry pairs sitting on the lit upper foliage
    berries = [(6, 7), (7, 8), (14, 5), (17, 8), (18, 9)]
    return bush(24, 18, blobs, berries)


def bush_b():
    blobs = [(10, 10, 9, 5), (6, 8, 5, 4), (14, 7, 5, 4)]
    return bush(20, 16, blobs, [])


def rock(w, h, blobs, notches, hi_block, crack, tufts):
    """Granite boulder: rounded silhouette, angular *internal* facet
    boundaries (quantized diagonals), small corner notches for character."""
    px = {}
    mask, _ = blob_mask(blobs, w, h)
    # clip below ground line (flat seat)
    mask = {p for p in mask if p[1] <= h - 2}
    # chip small corner notches out of the silhouette
    for (nx, ny, nw, nh) in notches:
        mask -= {(x, y) for x in range(nx, nx + nw) for y in range(ny, ny + nh)}
    cx = sum(p[0] for p in mask) / len(mask)
    cy = sum(p[1] for p in mask) / len(mask)
    for (x, y) in mask:
        bx = (x // 2) * 2 + 1.0
        by = (y // 2) * 2 + 1.0
        # angular facet shading: diagonal boundaries -> chiseled planes
        t = (bx - cx) * 0.35 + (by - cy) * 1.0
        if t < -0.5:
            c = STONE[2]
        elif t < 2.2:
            c = STONE[1]
        else:
            c = STONE[0]
        px[(x, y)] = c
    # facet highlight slab, top-left
    hx, hy = hi_block
    for dx in range(3):
        for dy in range(2):
            if (hx + dx, hy + dy) in mask:
                px[(hx + dx, hy + dy)] = STONE[3]
    # short diagonal crack
    for (x, y) in crack:
        if (x, y) in mask:
            px[(x, y)] = STONE[0]
    outline(px, w, h)
    # grass tufts at base (after outline so they sit on top)
    for (x, y) in tufts:
        px[(x, y)] = GRASS_LT
        px[(x + 1, y)] = GRASS_LT
        px[(x, y - 1)] = GRASS_HI
    return render(px, w, h)


def rock_a():
    blobs = [(9, 7, 8, 5), (6, 5, 5, 4)]
    notches = [(15, 3, 3, 2), (1, 3, 2, 2)]
    crack = [(12, 4), (13, 5), (13, 6)]
    return rock(18, 12, blobs, notches, (4, 2), crack, [(1, 10), (14, 10)])


def rock_b():
    blobs = [(11, 9, 10, 6.5), (19, 11, 6.5, 4.5), (8, 6, 6, 4)]
    notches = [(13, 3, 3, 2), (22, 7, 3, 2)]
    crack = [(15, 6), (16, 7), (16, 8), (17, 9)]
    return rock(26, 16, blobs, notches, (5, 3), crack, [(1, 14), (22, 14), (12, 15)])


PALE = C("a98756")   # pale cut-wood tone (from dirt ramp)


def stump():
    w, h = 20, 16
    px = {}
    # side (bark) -- kept dark so the pale top face pops
    for y in range(6, 15):
        extra = 1 if y >= 13 else 0
        x0, x1 = 3 - extra, 16 + extra
        for x in range(x0, x1 + 1):
            if x <= x0 + 1:
                c = WOOD[2]          # lit left
            elif x >= x1 - 2:
                c = WOOD[0]          # deep shadow right
            else:
                c = WOOD[1]
            px[(x, y)] = c
    # vertical bark grooves
    for gx in (7, 11):
        for y in range(7, 14):
            if (y + gx) % 4 != 0:
                px[(gx, y)] = WOOD[0]
    # top face (pale cut wood) with 2 lighter growth rings
    tcx, tcy, trx, try_ = 9.5, 5.0, 7.2, 3.4
    for y in range(1, 10):
        for x in range(2, 18):
            d = ((x - tcx) / trx) ** 2 + ((y - tcy) / try_) ** 2
            if d <= 1.0:
                px[(x, y)] = WOOD[3]
    # inner rim shadow on the bottom-right of the cut face (depth cue)
    for y in range(1, 10):
        for x in range(2, 18):
            d = ((x - tcx) / trx) ** 2 + ((y - tcy) / try_) ** 2
            if 0.80 <= d <= 1.0 and (x - tcx) * 0.6 + (y - tcy) > 0.8:
                px[(x, y)] = WOOD[2]
    # 2 clean 1px growth rings (parametric ellipse plot)
    import math
    for ring_r in (0.66, 0.33):
        for i in range(64):
            a = i / 64.0 * 2 * math.pi
            rx_ = int(round(tcx + trx * ring_r * math.cos(a)))
            ry_ = int(round(tcy + try_ * ring_r * math.sin(a)))
            if (rx_, ry_) in px:
                px[(rx_, ry_)] = PALE
    px[(int(tcx), int(tcy))] = PALE   # heart of the rings
    outline(px, w, h)
    return render(px, w, h)


def mushroom_cluster():
    w, h = 14, 12
    px = {}

    def shroom(cx, cap_y, stem_x, stem_h):
        # dome cap: rows of half-width 1,2,3
        for dy, hw in ((0, 1), (1, 2), (2, 3)):
            for x in range(cx - hw, cx + hw + 1):
                px[(x, cap_y + dy)] = RED
        # cap underside shadow row
        for x in range(cx - 2, cx + 3):
            px[(x, cap_y + 3)] = OUTLINE
        # stem
        for y in range(cap_y + 3, cap_y + 3 + stem_h):
            px[(stem_x, y)] = WHITE
            px[(stem_x + 1, y)] = STONE[3]

    shroom(4, 1, 4, 7)      # tall left mushroom
    shroom(10, 4, 10, 5)    # shorter right mushroom
    # white spots on caps
    px[(3, 2)] = WHITE
    px[(5, 3)] = WHITE
    px[(10, 5)] = WHITE
    outline(px, w, h)
    return render(px, w, h)


# ---------------------------------------------------------------- preview
def preview(sprites):
    pad = 8
    panel_h = max(s.height for _, s in sprites) + 12
    total_w = pad + sum(s.width + pad for _, s in sprites)
    panels = []
    for bg in ((0x3B, 0x72, 0x42, 255), (0x80, 0x80, 0x80, 255)):
        panel = Image.new("RGBA", (total_w, panel_h), bg)
        x = pad
        base = panel_h - 6
        for _, s in sprites:
            panel.alpha_composite(s, (x, base - s.height))
            x += s.width + pad
        panels.append(panel)
    sheet = Image.new("RGBA", (total_w, panel_h * 2), (0, 0, 0, 255))
    sheet.alpha_composite(panels[0], (0, 0))
    sheet.alpha_composite(panels[1], (0, panel_h))
    sheet = sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST)
    sheet.save("/tmp/props_preview.png")


def validate(name, img):
    """bottom margin <= 2px, fully binary alpha, no white-ish stray pixels."""
    w, h = img.size
    lowest = -1
    for y in range(h - 1, -1, -1):
        if any(img.getpixel((x, y))[3] > 0 for x in range(w)):
            lowest = y
            break
    margin = h - 1 - lowest
    assert margin <= 2, f"{name}: bottom margin {margin}px"
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            assert a in (0, 255), f"{name}: semi-transparent px at {x},{y}"
            if a == 255:
                assert not (r > 230 and g > 230 and b > 230 and (x, y) and
                            (r, g, b) != (0xE0, 0xE6, 0xEF)), \
                    f"{name}: stray white at {x},{y}"
    return margin


def detail_preview(sprites, names):
    """8x zoom strip of the small props on grass."""
    small = [(n, s) for n, s in zip(names, sprites)
             if s.width <= 26]
    pad = 4
    ph = max(s.height for _, s in small) + 8
    tw = pad + sum(s.width + pad for _, s in small)
    panel = Image.new("RGBA", (tw, ph), (0x3B, 0x72, 0x42, 255))
    x = pad
    for _, s in small:
        panel.alpha_composite(s, (x, ph - 4 - s.height))
        x += s.width + pad
    panel = panel.resize((panel.width * 8, panel.height * 8), Image.NEAREST)
    panel.save("/tmp/props_detail.png")


def main():
    jobs = [
        ("tree_oak_a", tree_oak_a()),
        ("tree_oak_b", tree_oak_b()),
        ("tree_pine", tree_pine()),
        ("bush_a", bush_a()),
        ("bush_b", bush_b()),
        ("rock_a", rock_a()),
        ("rock_b", rock_b()),
        ("stump", stump()),
        ("mushroom_cluster", mushroom_cluster()),
    ]
    for name, img in jobs:
        m = validate(name, img)
        img.save(f"{OUT}/{name}.png")
        print(name, img.size, f"bottom-margin={m}")
    preview(jobs)
    detail_preview([j[1] for j in jobs], [j[0] for j in jobs])
    print("previews -> /tmp/props_preview.png /tmp/props_detail.png")


if __name__ == "__main__":
    main()
