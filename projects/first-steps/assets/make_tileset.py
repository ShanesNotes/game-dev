"""Generate tileset.png (4 tiles, 32x32: grass, dirt, stone, grass-variant)
and shadow.png (soft blob for under actors/trees). Deterministic."""
import random
from PIL import Image, ImageDraw

random.seed(7)
T = 32

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def grass_tile(variant=False):
    base = (62, 110, 56)
    dark = (52, 96, 48)
    light = (78, 128, 64)
    im = Image.new('RGB', (T, T), base)
    px = im.load()
    # soft mottling in 2x2 clumps so it reads calm, not noisy
    for y in range(0, T, 2):
        for x in range(0, T, 2):
            r = random.random()
            c = dark if r < 0.22 else (light if r > 0.85 else base)
            for dy in range(2):
                for dx in range(2):
                    px[x + dx, y + dy] = c
    # sparse grass blades
    for _ in range(10):
        x, y = random.randrange(1, T - 1), random.randrange(2, T - 1)
        px[x, y] = (96, 146, 74)
        px[x, y - 1] = (88, 138, 70)
    if variant:
        # undergrowth: darker patch + tiny flowers
        for _ in range(26):
            x, y = random.randrange(T), random.randrange(T)
            px[x, y] = (44, 84, 44)
        for _ in range(3):
            x, y = random.randrange(2, T - 2), random.randrange(2, T - 2)
            px[x, y] = random.choice([(214, 208, 130), (196, 142, 170)])
    return im

def dirt_tile():
    base = (133, 102, 70)
    im = Image.new('RGB', (T, T), base)
    px = im.load()
    for y in range(0, T, 2):
        for x in range(0, T, 2):
            r = random.random()
            c = (121, 91, 61) if r < 0.25 else ((145, 113, 79) if r > 0.82 else base)
            for dy in range(2):
                for dx in range(2):
                    px[x + dx, y + dy] = c
    # pebbles and ruts
    for _ in range(7):
        x, y = random.randrange(1, T - 1), random.randrange(1, T - 1)
        px[x, y] = (158, 130, 96)
        px[x + 1, y] = (110, 82, 55)
    for _ in range(4):
        x, y = random.randrange(2, T - 4), random.randrange(T)
        for dx in range(3):
            px[x + dx, y] = (118, 88, 58)
    return im

def stone_tile():
    grout = (104, 102, 92)
    im = Image.new('RGB', (T, T), grout)
    d = ImageDraw.Draw(im)
    # irregular cobbles on a staggered grid
    for row in range(4):
        for col in range(4):
            x = col * 8 + (4 if row % 2 else 0)
            y = row * 8
            shade = random.uniform(-0.12, 0.14)
            c = lerp((142, 140, 128), (255, 255, 255), max(shade, 0)) if shade > 0 \
                else lerp((142, 140, 128), (90, 88, 80), -shade * 3)
            for ox in ((0, -T) if x + 7 >= T else (0,)):
                d.rounded_rectangle([x + 1 + ox, y + 1, x + 7 + ox, y + 7], radius=2, fill=c)
                d.point((x + 2 + ox, y + 2), fill=lerp(c, (255, 255, 255), 0.25))
    # wrap seam: copy left column to right edge zone is handled by stagger
    return im.crop((0, 0, T, T))

tiles = [grass_tile(), dirt_tile(), stone_tile(), grass_tile(variant=True)]
sheet = Image.new('RGBA', (T * 4, T))
for i, t in enumerate(tiles):
    sheet.paste(t, (i * T, 0))
sheet.save('tileset.png')

# soft elliptical shadow, 24x10
sh = Image.new('RGBA', (24, 10), (0, 0, 0, 0))
d = ImageDraw.Draw(sh)
for i, a in enumerate([40, 70, 95]):
    d.ellipse([i * 2, i, 23 - i * 2, 9 - i], fill=(10, 14, 8, a))
sh.save('shadow.png')
print('wrote tileset.png + shadow.png')
