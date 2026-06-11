#!/usr/bin/env python3
"""Generate assets/terrain.png - 128x192 atlas: 4 cols x 6 rows of 32x32 tiles.

Row 0: grass variants (plain / mottled / blades / blades+flowers).
Row 1: dirt variants (plain / pebbles / wheel ruts / stone flecks).
Rows 2-5: 16 dual-grid dirt-over-grass transition tiles.
  tile index i = (row-2)*4 + col, corner bits: 1=TL 2=TR 4=BL 8=BR (bit set = dirt corner).
  Mask = union of radius-16 circles centered on dirt corners (complement of the
  grass-corner circle when 3 corners are dirt). Tile 0 transparent, tile 15 full dirt.

Deterministic (fixed seed). Also writes previews to /tmp/.
"""
import random
from PIL import Image

SEED = 0xF1257
T = 32


def hx(s):
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


# master palette
GRASS_DK = hx("365f2b")
GRASS    = hx("4a7a38")
GRASS_LT = hx("6f9e4a")
BLADE    = hx("86bb58")

DIRT_EDGE = hx("5c4126")
DIRT_SH   = hx("6e4f31")
DIRT      = hx("8a6a45")
DIRT_LT   = hx("a98756")

STONE_DK  = hx("6b6b66")
STONE_MID = hx("8d8d85")

FL_Y = hx("e8d96f")
FL_P = hx("d98fb5")
FL_W = hx("e0e6ef")

CLEAR = (0, 0, 0, 0)

# small clustered shapes (never single-pixel speckle)
SHAPES = [
    [(0, 0), (1, 0), (0, 1), (1, 1)],   # 2x2
    [(0, 0), (1, 0)],                   # 2x1
    [(0, 0), (0, 1)],                   # 1x2
    [(0, 0), (1, 0), (1, 1)],           # L
    [(0, 0), (0, 1), (1, 1)],           # L
    [(0, 0), (1, 0), (2, 0)],           # 3x1
]


def new_tex(color):
    return [[color for _ in range(T)] for _ in range(T)]


def scatter(tex, rng, color, count, min_d2=16, margin=None):
    """Scatter clustered clumps. margin=None -> toroidal wrap; else keep inside margin."""
    placed = []
    tries = 0
    while len(placed) < count and tries < 600:
        tries += 1
        shape = rng.choice(SHAPES)
        if margin is None:
            x, y = rng.randrange(T), rng.randrange(T)
        else:
            x = rng.randrange(margin, T - margin - 2)
            y = rng.randrange(margin, T - margin - 2)
        if any((x - px) ** 2 + (y - py) ** 2 < min_d2 for px, py in placed):
            continue
        for dx, dy in shape:
            tex[(y + dy) % T][(x + dx) % T] = color
        placed.append((x, y))
    return placed


def blob(tex, rng, color, size, at=None, keep_in=None):
    """Compact toroidal random-growth patch (organic, always clustered).

    keep_in=(lo, hi): clamp growth to that coord range (no wrap) so tile
    variants never alter the shared edge ring.
    """
    if at is None:
        at = (rng.randrange(T), rng.randrange(T))
    cells = {at}
    while len(cells) < size:
        # grow from the cell with the most filled neighbors -> compact shapes
        frontier = []
        for (cx, cy) in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = ((cx + dx) % T, (cy + dy) % T)
                if keep_in is not None:
                    nx, ny = cx + dx, cy + dy
                    if not (keep_in[0] <= nx <= keep_in[1]
                            and keep_in[0] <= ny <= keep_in[1]):
                        continue
                    n = (nx, ny)
                if n not in cells:
                    score = sum(((n[0] + ax) % T, (n[1] + ay) % T) in cells
                                for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                    frontier.append((score, rng.random(), n))
        frontier.sort(reverse=True)
        cells.add(frontier[0][2])
    for (cx, cy) in cells:
        tex[cy][cx] = color
    return cells


def tex_to_img(tex):
    img = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), tex[y][x])
    return img


def copy_tex(tex):
    return [row[:] for row in tex]


# ---------------------------------------------------------------- base textures
def build_grass_base(rng):
    tex = new_tex(GRASS)
    for _ in range(5):                       # fewer, larger dark patches
        cells = blob(tex, rng, GRASS_DK, rng.randrange(4, 8))
        if rng.random() < 0.6:               # lit top-left edge on some tufts
            cx, cy = min(cells, key=lambda c: (c[0] + c[1], c))
            tex[(cy - 1) % T][cx] = GRASS_LT
            tex[(cy - 1) % T][(cx + 1) % T] = GRASS_LT
    for _ in range(3):
        blob(tex, rng, GRASS_LT, rng.randrange(3, 6))
    return tex


def build_dirt_base(rng):
    tex = new_tex(DIRT)
    for _ in range(7):
        blob(tex, rng, DIRT_SH, rng.randrange(4, 8))
    for _ in range(5):
        blob(tex, rng, DIRT_LT, rng.randrange(4, 6))  # compact, no glyph-y L3s
    return tex


# ---------------------------------------------------------------- grass variants
def grass_plain(base):
    return copy_tex(base)


def grass_mottled(base, rng):
    tex = copy_tex(base)
    for _ in range(3):
        x = rng.randrange(3, T - 4)
        y = rng.randrange(3, T - 4)
        blob(tex, rng, GRASS_DK, rng.randrange(4, 7), at=(x, y), keep_in=(1, T - 2))
    for _ in range(2):
        x = rng.randrange(3, T - 4)
        y = rng.randrange(3, T - 4)
        blob(tex, rng, GRASS_LT, rng.randrange(3, 5), at=(x, y), keep_in=(1, T - 2))
    return tex


def draw_blade(tex, x, y):
    """2-3px blade: light base, bright tip above (light from top-left)."""
    tex[y][x] = GRASS_LT
    tex[y - 1][x] = BLADE
    return tex


def grass_blades(base, rng, n=5):
    tex = copy_tex(base)
    spots = []
    tries = 0
    while len(spots) < n and tries < 200:
        tries += 1
        x = rng.randrange(2, T - 2)
        y = rng.randrange(3, T - 2)
        if any((x - px) ** 2 + (y - py) ** 2 < 49 for px, py in spots):
            continue
        draw_blade(tex, x, y)
        spots.append((x, y))
    return tex, spots


def grass_flowers(base, rng):
    tex, spots = grass_blades(base, rng, n=4)
    colors = [FL_Y, FL_P, FL_W]
    bands = [(2, 11), (12, 21), (22, T - 3)]   # vertical spread, no flower rows
    rng.shuffle(bands)
    placed = list(spots)
    for c, (y0, y1) in zip(colors, bands):
        for _ in range(60):
            x = rng.randrange(2, T - 3)
            y = rng.randrange(y0, y1)
            if any((x - px) ** 2 + (y - py) ** 2 < 64 for px, py in placed):
                continue
            # 2x2 flower head + stem shadow, in a small cluster of 2 so it
            # reads as flora rather than a stuck pixel
            for hx_, hy_ in ((x, y), (x + 3, y + rng.choice((-1, 1)))):
                for dx in (0, 1):
                    for dy in (0, 1):
                        tex[(hy_ + dy) % T][(hx_ + dx) % T] = c
                tex[(hy_ + 2) % T][hx_ % T] = GRASS_DK
            placed.append((x, y))
            break
    return tex


# ---------------------------------------------------------------- dirt variants
def dirt_plain(base):
    return copy_tex(base)


def dirt_pebbles(base, rng):
    tex = copy_tex(base)
    placed = []
    n = 0
    tries = 0
    while n < 5 and tries < 200:
        tries += 1
        x = rng.randrange(2, T - 3)
        y = rng.randrange(2, T - 3)
        if any((x - px) ** 2 + (y - py) ** 2 < 49 for px, py in placed):
            continue
        if rng.random() < 0.5:           # 3px stone
            tex[y][x] = DIRT_LT
            tex[y][x + 1] = DIRT_LT
            tex[y + 1][x] = DIRT_EDGE
        else:                            # 2px stone
            tex[y][x] = DIRT_LT
            tex[y + 1][x] = DIRT_EDGE
        placed.append((x, y))
        n += 1
    return tex


def dirt_ruts(base, rng):
    tex = copy_tex(base)
    for ry in (10, 21):
        # broken dashed groove with vertical jitter so rows never line up
        # across tile repeats (no scanline artifact)
        x = rng.randrange(4)
        while x < T - 3:
            run = rng.randrange(2, 5)
            jy = ry + rng.choice((-1, 0, 0, 1))
            for k in range(run):
                tex[jy][(x + k) % T] = DIRT_SH
            if rng.random() < 0.4:
                tex[(jy + 1) % T][(x + rng.randrange(run)) % T] = DIRT_LT
            x += run + rng.randrange(4, 9)
    return tex


def dirt_flecks(base, rng):
    tex = copy_tex(base)
    placed = []
    n = 0
    tries = 0
    while n < 4 and tries < 200:
        tries += 1
        x = rng.randrange(2, T - 3)
        y = rng.randrange(2, T - 3)
        if any((x - px) ** 2 + (y - py) ** 2 < 64 for px, py in placed):
            continue
        # embedded stone: lit top-left, dark flank, grounded by a dirt shadow
        tex[y][x] = STONE_MID
        tex[y][x + 1] = STONE_DK
        tex[y + 1][x] = STONE_DK
        tex[y + 1][x + 1] = DIRT_EDGE
        placed.append((x, y))
        n += 1
    return tex


# ---------------------------------------------------------------- transitions
CORNERS = {1: (0, 0), 2: (32, 0), 4: (0, 32), 8: (32, 32)}
R2 = 16 * 16


def mask_fn(bits):
    if bits == 15:
        return lambda x, y: True
    if bits == 0:
        return lambda x, y: False
    set_bits = [b for b in (1, 2, 4, 8) if bits & b]
    if len(set_bits) == 3:
        gb = [b for b in (1, 2, 4, 8) if not bits & b][0]
        gx, gy = CORNERS[gb]
        return lambda x, y: (x + 0.5 - gx) ** 2 + (y + 0.5 - gy) ** 2 > R2
    pts = [CORNERS[b] for b in set_bits]
    return lambda x, y: any(
        (x + 0.5 - px) ** 2 + (y + 0.5 - py) ** 2 <= R2 for px, py in pts
    )


def render_transition(bits, dirt_tex, rng, rough_seed=0):
    img = Image.new("RGBA", (T, T), CLEAR)
    if bits == 0:
        return img
    m = mask_fn(bits)
    # materialize the mask over an extended window so rim checks past tile
    # bounds stay consistent, then roughen the boundary ONLY in the tile
    # interior (>=3px from every edge) — edge crossings stay exactly on the
    # radius-16 contract, so variants still join seamlessly.
    ext = {}
    for y in range(-2, T + 2):
        for x in range(-2, T + 2):
            ext[(x, y)] = m(x, y)
    rrng = random.Random(rough_seed * 7919 + bits * 131 + SEED)
    band = [(x, y) for y in range(3, T - 3) for x in range(3, T - 3)
            if any(ext[(x + dx, y + dy)] != ext[(x, y)]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for (x, y) in band:
        r = rrng.random()
        if r < 0.18:
            ext[(x, y)] = True    # dirt nibbles outward
        elif r < 0.36:
            ext[(x, y)] = False   # grass bites inward
    # de-speckle: a flipped pixel surrounded by the opposite state reverts
    for (x, y) in band:
        n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if ext[(x + dx, y + dy)] == ext[(x, y)])
        if n == 0:
            ext[(x, y)] = not ext[(x, y)]
    inside = set()
    for y in range(T):
        for x in range(T):
            if ext[(x, y)]:
                img.putpixel((x, y), dirt_tex[y][x])
                inside.add((x, y))
    if bits == 15:
        return img
    # 1px dark edge just inside the boundary
    for (x, y) in inside:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if not ext[(x + dx, y + dy)]:
                img.putpixel((x, y), DIRT_EDGE)
                break
    # sparse grass tufts overhanging just outside the boundary
    outside = []
    for y in range(T):
        for x in range(T):
            if (x, y) in inside:
                continue
            if any((x + dx, y + dy) in inside
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                outside.append((x, y))
    rng.shuffle(outside)
    chosen = []
    for (x, y) in outside:
        if any((x - cx) ** 2 + (y - cy) ** 2 < 40 for cx, cy in chosen):
            continue
        if rng.random() > 0.65:
            continue
        img.putpixel((x, y), GRASS_LT)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < T and 0 <= ny < T and (nx, ny) not in inside \
                    and img.getpixel((nx, ny))[3] == 0:
                img.putpixel((nx, ny), GRASS_LT)
                break
        chosen.append((x, y))
    return img


# ---------------------------------------------------------------- atlas
def build_atlas():
    rng = random.Random(SEED)
    grass_base = build_grass_base(rng)
    dirt_base = build_dirt_base(rng)

    grass_tiles = [
        grass_plain(grass_base),
        grass_mottled(grass_base, rng),
        grass_blades(grass_base, rng)[0],
        grass_flowers(grass_base, rng),
    ]
    dirt_tiles = [
        dirt_plain(dirt_base),
        dirt_pebbles(dirt_base, rng),
        dirt_ruts(dirt_base, rng),
        dirt_flecks(dirt_base, rng),
    ]

    # 3 roughness variants of the 16 transitions: rows 2-5, 6-9, 10-13
    atlas = Image.new("RGBA", (4 * T, 14 * T), CLEAR)
    for c, tex in enumerate(grass_tiles):
        atlas.paste(tex_to_img(tex), (c * T, 0))
    for c, tex in enumerate(dirt_tiles):
        atlas.paste(tex_to_img(tex), (c * T, T))
    for v in range(3):
        for i in range(16):
            col, row = i % 4, 2 + v * 4 + i // 4
            atlas.paste(render_transition(i, dirt_base, rng, rough_seed=v), (col * T, row * T))
    return atlas, grass_tiles


# ---------------------------------------------------------------- demo + previews
def seg_dist2(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    L2 = vx * vx + vy * vy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / L2))
    dx, dy = px - (ax + t * vx), py - (ay + t * vy)
    return dx * dx + dy * dy


def path_node_grid():
    """9x9 boolean node grid: curvy path, hand-made polyline."""
    poly = [(-0.5, 2.2), (1.8, 2.8), (3.5, 4.5), (3.2, 6.4),
            (5.0, 7.2), (7.2, 6.0), (8.5, 6.2)]
    nodes = set()
    for ny in range(9):
        for nx in range(9):
            d2 = min(seg_dist2(nx, ny, *poly[k], *poly[k + 1])
                     for k in range(len(poly) - 1))
            if d2 < 1.05 * 1.05:
                nodes.add((nx, ny))
    return nodes


def build_demo(atlas):
    rng = random.Random(SEED + 1)
    nodes = path_node_grid()
    demo = Image.new("RGBA", (8 * T, 8 * T))
    weights = [0.35, 0.35, 0.2, 0.1]
    for ty in range(8):
        for tx in range(8):
            v = rng.choices(range(4), weights)[0]
            tile = atlas.crop((v * T, 0, v * T + T, T))
            demo.paste(tile, (tx * T, ty * T))
    for ty in range(8):
        for tx in range(8):
            bits = ((1 if (tx, ty) in nodes else 0)
                    | (2 if (tx + 1, ty) in nodes else 0)
                    | (4 if (tx, ty + 1) in nodes else 0)
                    | (8 if (tx + 1, ty + 1) in nodes else 0))
            if bits == 0:
                continue
            col, row = bits % 4, 2 + bits // 4
            tile = atlas.crop((col * T, row * T, col * T + T, row * T + T))
            demo.alpha_composite(tile, (tx * T, ty * T))
    return demo


def build_previews(atlas):
    pad = 16
    w = pad * 3 + atlas.width * 2
    h = pad * 2 + atlas.height
    prev = Image.new("RGBA", (w, h), GRASS)
    for y in range(h):
        for x in range(w // 2, w):
            prev.putpixel((x, y), (128, 128, 128, 255))
    prev.alpha_composite(atlas, (pad, pad))
    prev.alpha_composite(atlas, (pad * 2 + atlas.width, pad))
    prev = prev.resize((w * 4, h * 4), Image.NEAREST)
    prev.save("/tmp/terrain_preview.png")

    demo = build_demo(atlas)
    demo.resize((demo.width * 4, demo.height * 4), Image.NEAREST) \
        .save("/tmp/terrain_demo.png")

    # self-tiling quilts: each base tile 2x2 of itself, plus mixed quilts
    rng = random.Random(SEED + 2)
    quilt = Image.new("RGBA", (8 + 4 * (2 * T + 8), 8 + 4 * (2 * T + 8)),
                      (32, 32, 32, 255))
    for r in range(2):           # row 0: grass tiles, row 1: dirt tiles
        for c in range(4):
            tile = atlas.crop((c * T, r * T, c * T + T, r * T + T))
            ox = 8 + c * (2 * T + 8)
            oy = 8 + r * (2 * T + 8)
            for qy in range(2):
                for qx in range(2):
                    quilt.paste(tile, (ox + qx * T, oy + qy * T))
    # mixed quilts (random variants) to test cross-variant seams
    for r, base_row in ((2, 0), (3, 1)):
        for c in range(4):
            ox = 8 + c * (2 * T + 8)
            oy = 8 + r * (2 * T + 8)
            for qy in range(2):
                for qx in range(2):
                    v = rng.randrange(4)
                    tile = atlas.crop((v * T, base_row * T,
                                       v * T + T, base_row * T + T))
                    quilt.paste(tile, (ox + qx * T, oy + qy * T))
    quilt.resize((quilt.width * 4, quilt.height * 4), Image.NEAREST) \
        .save("/tmp/terrain_tiling.png")


def main():
    atlas, _ = build_atlas()
    atlas.save("terrain.png")
    build_previews(atlas)
    print("wrote terrain.png + /tmp/terrain_preview.png "
          "+ /tmp/terrain_demo.png + /tmp/terrain_tiling.png")


if __name__ == "__main__":
    main()
