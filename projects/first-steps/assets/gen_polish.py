"""Critique-pass polish: conform the hero to the pixel-art language, rebuild
the portrait as a head bust, relight the wolf, harden shadows, warm the
vignette, give bar troughs a visible border, and add a target ring.
Deterministic; operates on already-generated assets in place."""
import random
from PIL import Image

random.seed(11)
OUTLINE = (26, 20, 15)

def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# ---------------------------------------------------------------- hero conform
# Warm the near-black hair/gear mass to readable chestnut, add a top-left
# hair highlight, brighten skin, leave the 1px outline untouched.
CHESTNUT = (98, 54, 33)
CHESTNUT_HI = (138, 79, 46)

def conform_hero():
    im = Image.open('character_clean.png').convert('RGBA')
    px = im.load()
    W, H = im.size
    is_dark = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            p = (r, g, b)
            if p == OUTLINE or abs(r - 26) + abs(g - 20) + abs(b - 15) <= 6:
                continue   # outline stays
            L = lum(p)
            if L < 52:                       # hair / scabbard / boots mass
                px[x, y] = lerp(p, CHESTNUT, 0.62) + (a,)
                is_dark[y][x] = True
            elif r > 130 and r > g > b and g > 70:   # skin
                px[x, y] = (min(int(r * 1.06), 255), min(int(g * 1.05), 255), min(int(b * 1.02), 255), a)
    # top-left highlight band on the warmed mass (light from upper-left)
    for y in range(H):
        for x in range(W):
            if not is_dark[y][x]:
                continue
            above = px[x, y - 1] if y > 0 else (0, 0, 0, 0)
            left = px[x - 1, y] if x > 0 else (0, 0, 0, 0)
            above_open = above[3] == 0 or (above[0], above[1], above[2]) == OUTLINE
            if above_open or (y % 32 < 12 and left[3] == 0):
                px[x, y] = CHESTNUT_HI + (255,)
    im.save('character_clean.png')

# ---------------------------------------------------------------- portrait bust
def make_portrait():
    sheet = Image.open('character_clean.png').convert('RGBA')
    frame = sheet.crop((0, 0, 32, 32))
    # find sprite bbox, take the head (top ~12 rows), pixel-double it
    bbox = frame.getbbox()
    # skip the crown of hair; frame the face and shoulders. 20x20 output so
    # the 40px HUD rect is an exact 2x integer scale (no wobbly pixels).
    cx = (bbox[0] + bbox[2]) // 2
    head = frame.crop((cx - 5, bbox[1] + 4, cx + 5, bbox[1] + 14))
    head = Image.eval(head, lambda v: min(int(v * 1.18), 255))
    out = Image.new('RGBA', (20, 20), (0, 0, 0, 0))
    out.paste(head.resize((20, 20), Image.NEAREST), (0, 0), head.resize((20, 20), Image.NEAREST))
    out.save('portrait_hero.png')

# ---------------------------------------------------------------- wolf relight
def relight_wolf():
    im = Image.open('wolf_sheet.png').convert('RGBA')
    px = im.load()
    W, H = im.size
    GRAYS = {(85, 85, 79), (107, 107, 102), (141, 141, 133)}
    LIGHT = (141, 141, 133)
    MID = (107, 107, 102)
    DARK = (85, 85, 79)
    orig = {(x, y): px[x, y] for y in range(H) for x in range(W)}
    for y in range(H):
        for x in range(W):
            r, g, b, a = orig[(x, y)]
            if a == 0 or (r, g, b) not in GRAYS:
                continue
            up = orig.get((x, y - 1), (0, 0, 0, 0))
            dn = orig.get((x, y + 1), (0, 0, 0, 0))
            up_closed = up[3] == 0 or (up[0], up[1], up[2]) == OUTLINE
            dn_closed = dn[3] == 0 or (dn[0], dn[1], dn[2]) == OUTLINE
            if up_closed and (r, g, b) != LIGHT:
                px[x, y] = LIGHT + (255,)       # lit back/head ridge
            elif dn_closed and (r, g, b) == MID:
                px[x, y] = DARK + (255,)        # shaded underbelly line
    im.save('wolf_sheet.png')

# ---------------------------------------------------------------- hard shadow
def make_shadow():
    w, h = 24, 10
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = ((x - cx) / (w / 2)) ** 2 + ((y - cy) / (h / 2)) ** 2
            if d <= 0.55:
                px[x, y] = (12, 16, 9, 88)            # solid core
            elif d <= 1.0 and (x + y) % 2 == 0:
                px[x, y] = (12, 16, 9, 70)            # dither ring
    im.save('shadow.png')

# ---------------------------------------------------------------- warm vignette
def make_vignette():
    w, h = 480, 270
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(h):
        for x in range(w):
            nx, ny = (x / w - 0.5) * 2, (y / h - 0.5) * 2
            d = (nx * nx + ny * ny) ** 0.5
            t = max(0.0, min(1.0, (d - 0.55) / 0.65))
            t = t * t * (3 - 2 * t)
            a = t * 66 + (BAYER[y % 4][x % 4] - 7.5) / 16.0
            a = max(0, min(255, int(a)))
            if a > 0:
                px[x, y] = (40, 28, 12, a)
    im.save('vignette.png')

# ---------------------------------------------------------------- bar trough
def make_bar_bg():
    im = Image.new('RGBA', (64, 12), (0, 0, 0, 0))
    px = im.load()
    for y in range(12):
        for x in range(64):
            if x == 0 or x == 63 or y == 0 or y == 11:
                px[x, y] = (107, 90, 58, 255)     # visible bronze border
            elif y == 1:
                px[x, y] = (14, 11, 8, 255)       # inner top shadow
            else:
                px[x, y] = (34, 23, 16, 255)      # warm dark trough
    im.save('ui_bar_bg.png')

# ---------------------------------------------------------------- target ring
def make_target_ring():
    w, h = 28, 14
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = ((x - cx) / (w / 2 - 0.5)) ** 2 + ((y - cy) / (h / 2 - 0.5)) ** 2
            if 0.62 <= d <= 1.0:
                px[x, y] = (232, 217, 111, 230) if y <= cy else (199, 178, 75, 230)
    im.save('target_ring.png')

# ---------------------------------------------------------------- held sword
# Bake the 25-degree rest pose into the texture so the standing hero's blade
# sits on the art grid (runtime rotation only during the brief swing).
def make_sword_held():
    im = Image.open('sword_clean.png').convert('RGBA')
    rot = im.rotate(-25, resample=Image.NEAREST, expand=False)
    rot.save('sword_held.png')

# ---------------------------------------------------------------- camp props
WOOD_D, WOOD, WOOD_L = (58, 40, 23), (107, 74, 43), (138, 101, 60)
STONE_D, STONE, STONE_L = (85, 85, 79), (107, 107, 102), (141, 141, 133)

def make_campfire():
    w, h = 18, 14
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    # stone ring
    ring = [(3, 11), (6, 12), (9, 13), (12, 12), (15, 11), (2, 10), (16, 10)]
    for x, y in ring:
        px[x, y] = STONE
        if x + 1 < w: px[x + 1, y] = STONE_L
        if y + 1 < h: px[x, min(y + 1, h - 1)] = STONE_D
    # crossed logs
    for i in range(7):
        px[5 + i, 11 - i // 3] = WOOD
        px[12 - i, 11 - i // 3] = WOOD_D
    # flame: layered teardrop
    flame = [(9, 4, (255, 222, 89)), (8, 5, (255, 222, 89)), (9, 5, (255, 222, 89)),
             (10, 5, (245, 158, 49)), (8, 6, (245, 158, 49)), (9, 6, (255, 222, 89)),
             (10, 6, (245, 158, 49)), (7, 7, (245, 158, 49)), (9, 7, (255, 245, 180)),
             (10, 7, (245, 158, 49)), (11, 7, (201, 79, 36)), (8, 7, (245, 158, 49)),
             (7, 8, (201, 79, 36)), (8, 8, (245, 158, 49)), (9, 8, (255, 222, 89)),
             (10, 8, (245, 158, 49)), (11, 8, (201, 79, 36)),
             (8, 9, (201, 79, 36)), (9, 9, (245, 158, 49)), (10, 9, (201, 79, 36)),
             (9, 3, (245, 158, 49))]
    for x, y, c in flame:
        px[x, y] = c + (255,)
    im.save('campfire.png')

def make_signpost():
    w, h = 18, 26
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(4, 26):   # post
        px[8, y] = WOOD
        px[9, y] = WOOD_D
    for y, (x0, x1) in ((5, (2, 14)), (11, (4, 16))):   # two boards
        for x in range(x0, x1):
            px[x, y] = WOOD_L
            px[x, y + 1] = WOOD
            px[x, y + 2] = WOOD_D
        # arrow tip
        px[x1, y + 1] = WOOD
        px[x0 - 1, y + 1] = WOOD if y == 11 else px[x0 - 1, y + 1]
    # outline-ish grounding
    for y in range(24, 26):
        px[7, y] = WOOD_D
    im.save('signpost.png')

conform_hero()
make_portrait()
relight_wolf()
make_shadow()
make_vignette()
make_bar_bg()
make_target_ring()
make_sword_held()
make_campfire()
make_signpost()
print('polish pass complete')
