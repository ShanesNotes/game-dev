#!/usr/bin/env python3
"""gen_creatures.py — creature sprite cleanup + wolf sheet for first-steps.

Outputs:
  character_clean.png  128x128  rows: 0=down 1=left 2=right 3=up
  wolf_sheet.png       128x32   [idle, run A, run B, attack lunge], facing left
  sword_clean.png      32x32    white bg cleared, hilt re-hit in UI gold
  portrait_hero.png    24x24    head & shoulders of front-facing hero

Deterministic: no random drawing, but seed fixed anyway.
"""
import random
from PIL import Image

random.seed(42)

OUTLINE = (0x1A, 0x14, 0x0F, 255)
GRASS = (0x3B, 0x72, 0x42, 255)
GRAY_BG = (0x80, 0x80, 0x80, 255)

# ---------------------------------------------------------------- helpers

def binarize_alpha(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return img


def strip_light_halo(img, thresh=190, sat_max=45, lum_thresh=165):
    """Remove background remnants that touch transparency or the frame edge:
    near-white low-saturation pixels, plus any bright (lum > lum_thresh)
    moderately-unsaturated pixel (tan/khaki AA rim). Iterates so connected
    white slabs peel away completely."""
    px = img.load()
    W, H = img.size
    while True:
        kill = []
        for y in range(H):
            for x in range(W):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                sat = max(r, g, b) - min(r, g, b)
                near_white = min(r, g, b) >= thresh and sat <= sat_max
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                bright_rim = lum > lum_thresh and sat <= 90
                if not (near_white or bright_rim):
                    continue
                edge = x in (0, W - 1) or y in (0, H - 1)
                near_trans = any(
                    px[x + dx, y + dy][3] == 0
                    for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                    if (dx or dy) and 0 <= x + dx < W and 0 <= y + dy < H
                )
                if edge or near_trans:
                    kill.append((x, y))
        if not kill:
            return img
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)


def drop_small_components(img, min_size=8):
    """Remove opaque 8-connected components smaller than min_size pixels."""
    px = img.load()
    W, H = img.size
    seen = set()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0 or (x, y) in seen:
                continue
            comp = [(x, y)]
            seen.add((x, y))
            stack = [(x, y)]
            while stack:
                cx, cy = stack.pop()
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen
                                and px[nx, ny][3] > 0):
                            seen.add((nx, ny))
                            comp.append((nx, ny))
                            stack.append((nx, ny))
            if len(comp) < min_size:
                for cx, cy in comp:
                    px[cx, cy] = (0, 0, 0, 0)
    return img


def boost(img, contrast=1.12, sat=1.08):
    """Mild contrast + saturation push so sprites pop against mid-green."""
    import colorsys
    px = img.load()
    cache = {}
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            key = p[:3]
            if key not in cache:
                r, g, b = (v / 255.0 for v in key)
                h, l, s = colorsys.rgb_to_hls(r, g, b)
                l = min(1.0, max(0.0, 0.5 + (l - 0.5) * contrast))
                s = min(1.0, s * sat)
                nr, ng, nb = colorsys.hls_to_rgb(h, l, s)
                cache[key] = (int(nr * 255 + 0.5), int(ng * 255 + 0.5), int(nb * 255 + 0.5))
            c = cache[key]
            px[x, y] = (c[0], c[1], c[2], 255)
    return img


def quantize_frame(img, n=15):
    """Median-cut the opaque colours of one frame down to <= n."""
    px = img.load()
    coords = [(x, y) for y in range(img.height) for x in range(img.width) if px[x, y][3] > 0]
    if not coords:
        return img
    colors = [px[x, y][:3] for x, y in coords]
    uniq = len(set(colors))
    if uniq <= n:
        return img
    strip = Image.new('RGB', (len(colors), 1))
    strip.putdata(colors)
    q = strip.quantize(colors=n, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
    remapped = list(q.convert('RGB').getdata())
    for (x, y), c in zip(coords, remapped):
        px[x, y] = (c[0], c[1], c[2], 255)
    return img


def outline(img, color=OUTLINE):
    """1px outline on transparent pixels 4-adjacent to opaque pixels."""
    px = img.load()
    W, H = img.size
    add = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] != 0:
                continue
            if any(
                px[x + dx, y + dy][3] > 0 and px[x + dx, y + dy][:3] != color[:3]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= x + dx < W and 0 <= y + dy < H
            ):
                add.append((x, y))
    for x, y in add:
        px[x, y] = color
    return img


def frames_of(sheet, fw=32, fh=32):
    return [
        [sheet.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
         for c in range(sheet.width // fw)]
        for r in range(sheet.height // fh)
    ]


# ---------------------------------------------------------------- character

def build_character():
    src = Image.open('character.png').convert('RGBA')
    rows = frames_of(src)

    def clean(frame):
        frame = binarize_alpha(frame.copy())
        frame = strip_light_halo(frame)
        frame = drop_small_components(frame)
        frame = boost(frame, contrast=1.12, sat=1.05)
        frame = quantize_frame(frame, 15)
        frame = outline(frame)
        return frame

    cleaned = [[clean(f) for f in row] for row in rows]

    # row1 = canonical right-facing profile (row2 is the odd duplicate).
    right = cleaned[1]
    left = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in right]

    sheet = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    for r, row in enumerate([cleaned[0], left, right, cleaned[3]]):
        for c, f in enumerate(row):
            sheet.paste(f, (c * 32, r * 32))
    sheet.save('character_clean.png')
    return sheet


# ---------------------------------------------------------------- portrait

def build_portrait(sheet):
    front = sheet.crop((0, 0, 32, 32))  # row0 col0
    px = front.load()
    ys = [y for y in range(32) for x in range(32) if px[x, y][3] > 0]
    top = min(ys)
    head_xs = [x for y in range(top, top + 9) for x in range(32) if px[x, y][3] > 0]
    cx = round(sum(head_xs) / len(head_xs))
    box = (max(0, cx - 12), max(0, top - 1), max(0, cx - 12) + 24, max(0, top - 1) + 24)
    crop = front.crop(box)
    # erase the staff sliver along the left edge of the crop (head & shoulders only)
    cpx = crop.load()
    for y in range(24):
        for x in range(STAFF_ERASE_X):
            cpx[x, y] = (0, 0, 0, 0)
    # stray warm background-tinted pixels along the upper hair edge
    for y in range(7):
        for x in range(12, 24):
            r, g, b, a = cpx[x, y]
            if a and r > b + 40 and 0.299 * r + 0.587 * g + 0.114 * b > 120:
                cpx[x, y] = (0, 0, 0, 0)
    crop = drop_small_components(crop, 6)
    crop = outline(crop)
    crop.save('portrait_hero.png')
    return crop


STAFF_ERASE_X = 7


# ---------------------------------------------------------------- wolf

W_PAL = {
    'd': (0x55, 0x55, 0x4F, 255),   # dark fur / ridge
    'm': (0x6B, 0x6B, 0x66, 255),   # mid fur
    'l': (0x8D, 0x8D, 0x85, 255),   # light fur (top-left light)
    'b': (0xB0, 0xAF, 0xA3, 255),   # pale belly / muzzle
    'e': (0xE0, 0xE6, 0xEF, 255),   # eye glint
    'r': (0xC9, 0x2F, 0x24, 255),   # tongue (attack)
    'o': OUTLINE[:3] + (255,),      # interior dark detail
}

# ruler:  0123456789012345678901234567890 1
#                   1111111111222222222233
WOLF_IDLE = [
    "", "", "", "", "",
    "...l....d",
    "...ll..dd",
    "...lll.ddd",
    "...llmmmdd",
    "..llmmmmmdd",
    "..ldemmmmdd",
    ".blmmmmmmdd",
    "obbmmmmmmddddddddddddddd",
    ".obmmmmmmdllllllllllllddd",
    "...dmmmmmlllllllllllmmddd",
    "....dmmmmmmmmmmmmmmmmmd.dd",
    "....dbbmmmmmmmmmmmmmmdd.ddm",
    "....dbbmmmmmmmmmmmmmmd...dmm",
    "....dbbbbbbbbbmmmmmmmd...dmm",
    ".....mbbbbbbbbmmmmmm.....dmm",
    ".....mmmbbbbbbmmmmmm......dm",
    ".....mmm..dd...dd.mmm",
    ".....mmm..dd...dd.mmm",
    "......mm..dd...dd..mm",
    "......mm..dd...dd..mm",
    "......mm..dd...dd..mm",
    ".....bmmb.dd...dd.bmmb",
]

WOLF_RUN_A = [
    "", "", "", "", "", "",
    "....l...d",
    "....ll.dd",
    "....llmmdd",
    "...llmmmmdd",
    "..ldemmmmdd",
    ".blmmmmmmmdd",
    "obbmmmmmmmdddddddddddddd.ddd",
    ".obmmmmmmmdlllllllllllddddmm",
    "...dmmmmmmlllllllllllmmddm",
    "....dmmmmmmmmmmmmmmmmmdd",
    "....dbbmmmmmmmmmmmmmmmd",
    "....dbbbbbbbbmmmmmmmmmd",
    ".....mbbbbbbbmmmmmmmmmm",
    "....mmmmbbbbbmmmmmmmmmmm",
    "...mmm...dd......dd..mmm",
    "..mmm.....dd......dd..mmm",
    ".mmm.......dd......dd..mmm",
    "bmm.........dd......dd..mmb",
    "",
    "",
]

WOLF_RUN_B = [
    "", "", "", "", "", "", "",
    ".....l..d",
    ".....ll.dd",
    ".....llmmdd",
    "....llmmmmdd",
    "...ldemmmmdd",
    "..blmmmmmmddddddddddddd",
    ".obbmmmmmmdllllllllllldd",
    "..obmmmmmmllllllllllmmdd",
    "....dmmmmmmmmmmmmmmmmmdd",
    ".....dbbmmmmmmmmmmmmmdd.dd",
    ".....dbbbbbbbmmmmmmmmd..ddm",
    "......mbbbbbbmmmmmmmm....dmm",
    "......mmmbbbbmmmmmmmm.....dm",
    ".......mm..dd...dd..mm",
    "........mm..dd.dd..mm",
    ".........mm..ddd..mm",
    "..........mmb...bmm",
    "",
    "",
]

WOLF_ATTACK = [
    "", "", "", "", "", "", "",
    "........................ddd",
    "......................dddd",
    "...............ddddddddddm",
    ".............ddddllllllddmm",
    "...........ddmmllllllllddm",
    ".........ddmmmmmmmmmmmmdd",
    "...dddd.dmmmmmmmmmmmmmmd",
    "..llmmddmmmmmmmmmmmmmmmd",
    ".lldemmmmmmmmmmmmmmmmmd",
    "blbmmmmmmmmmmmmmmmmmmmd",
    "obbbbboodmmbbbbmmmmmmmd",
    ".oeooo..dmbbbbbbmmmmmmd",
    ".orrro..mmbbbbbbmmmmmm",
    "..bbbo..mmm..mmm..dd.dd",
    "...oo..mmm....mmm..dd.dd",
    "......mmm.....mmm...dd.dd",
    ".....bmm......bmm....dd.ddb",
    "",
    "",
]


def map_to_image(rows, w=32, h=32):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row[:w]):
            if ch != '.' and ch != ' ':
                px[x, y] = W_PAL[ch]
    return img


def build_wolf():
    maps = [WOLF_IDLE, WOLF_RUN_A, WOLF_RUN_B, WOLF_ATTACK]
    sheet = Image.new('RGBA', (128, 32), (0, 0, 0, 0))
    for i, m in enumerate(maps):
        f = map_to_image(m)
        f = outline(f)
        sheet.paste(f, (i * 32, 0))
    sheet.save('wolf_sheet.png')
    return sheet


# ---------------------------------------------------------------- sword

GOLD = [(0x4A, 0x3A, 0x1C), (0x8A, 0x6D, 0x2F), (0xD4, 0xA8, 0x43), (0xF0, 0xD2, 0x7A)]


def build_sword():
    img = Image.open('sword.png').convert('RGBA')
    img = binarize_alpha(img)
    img = strip_light_halo(img)
    img = drop_small_components(img, 4)
    px = img.load()
    # re-hit warm (orange/brown) guard pixels in UI gold by luminance (hilt rows only)
    for y in range(19, 25):
        for x in range(32):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r >= 60 and r - b >= 20:
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                if lum < 80:
                    c = GOLD[0]
                elif lum < 130:
                    c = GOLD[1]
                elif lum < 185:
                    c = GOLD[2]
                else:
                    c = GOLD[3]
                px[x, y] = c + (255,)
    # the grip/pommel below the guard is AA mush in the source: redraw it clean
    WOOD = {'L': (0x8A, 0x65, 0x3C), 'w': (0x6B, 0x4A, 0x2B), 's': (0x4A, 0x33, 0x20)}
    for y in range(25, 32):
        for x in range(32):
            px[x, y] = (0, 0, 0, 0)
    grip = ["LwwsS", "LwwsS", "Lwws"]          # y25..27, x14..17
    for dy, row in enumerate(grip):
        for dx, ch in enumerate(row[:4]):
            px[14 + dx, 25 + dy] = WOOD.get(ch, WOOD['w']) + (255,)
    pommel = [
        (14, 28, GOLD[3]), (15, 28, GOLD[2]), (16, 28, GOLD[2]), (17, 28, GOLD[1]),
        (14, 29, GOLD[2]), (15, 29, GOLD[2]), (16, 29, GOLD[1]), (17, 29, GOLD[1]),
        (15, 30, GOLD[1]), (16, 30, GOLD[0]),
    ]
    for x, y, c in pommel:
        px[x, y] = c + (255,)
    img = quantize_frame(img, 15)
    img = outline(img)
    img.save('sword_clean.png')
    return img


# ---------------------------------------------------------------- previews

def on_bg(img, bg):
    c = Image.new('RGBA', img.size, bg)
    c.alpha_composite(img)
    return c


def preview(img, path, scale=5, pad=4):
    """Stack the sprite on grass and on gray, upscale NEAREST."""
    w, h = img.size
    canvas = Image.new('RGBA', (w + pad * 2, (h + pad) * 2 + pad), (20, 20, 20, 255))
    canvas.paste(on_bg(img, GRASS), (pad, pad))
    canvas.paste(on_bg(img, GRAY_BG), (pad, h + pad * 2))
    canvas = canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST)
    canvas.save(path)


def main():
    char = build_character()
    build_portrait(char)
    wolf = build_wolf()
    sword = build_sword()

    preview(char, '/tmp/prev_char_clean.png', scale=4)
    preview(wolf, '/tmp/prev_wolf.png', scale=6)
    preview(sword, '/tmp/prev_sword.png', scale=8)
    preview(Image.open('portrait_hero.png'), '/tmp/prev_portrait.png', scale=8)

    # mirror check: left row above right row
    strip = Image.new('RGBA', (128, 64), (0, 0, 0, 0))
    strip.paste(char.crop((0, 32, 128, 64)), (0, 0))
    strip.paste(char.crop((0, 64, 128, 96)), (0, 32))
    preview(strip, '/tmp/prev_mirror.png', scale=5)
    print('done')


if __name__ == '__main__':
    main()
