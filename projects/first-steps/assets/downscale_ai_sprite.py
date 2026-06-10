#!/usr/bin/env python3
"""
AI sprite -> Godot-ready downscaler + background keyer.

Usage:
  python downscale_ai_sprite.py character_source_1024.png 128 32 character.png
  python downscale_ai_sprite.py wolf_source.png 32 32 wolf.png --key-thresh 240

Takes high-res AI output (Grok Imagine etc.), resizes it to the target sheet
size, keys out the near-white background to transparency, then restores
contrast/saturation/sharpness lost in the downscale. See SPRITE_WORKFLOW.md.
Requires Pillow.
"""
from PIL import Image, ImageEnhance, ImageFilter
import argparse

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("width", type=int)
    ap.add_argument("height", type=int)
    ap.add_argument("output")
    ap.add_argument("--key-thresh", type=int, default=242, help="RGB value above which is treated as bg white to key out")
    ap.add_argument("--contrast", type=float, default=1.25)
    ap.add_argument("--sat", type=float, default=1.2)
    ap.add_argument("--unsharp", type=float, default=130)
    args = ap.parse_args()

    im = Image.open(args.input).convert("RGBA")
    print(f"Loaded {im.size} -> target {args.width}x{args.height}")

    im = im.resize((args.width, args.height), Image.LANCZOS)

    # White key
    datas = im.getdata()
    newd = []
    t = args.key_thresh
    for r,g,b,a in datas:
        if r > t and g > t and b > t:
            newd.append((255,255,255,0))
        else:
            newd.append((r,g,b,a))
    im.putdata(newd)

    # Recover pop after downscale
    im = ImageEnhance.Contrast(im).enhance(args.contrast)
    im = ImageEnhance.Color(im).enhance(args.sat)
    im = im.filter(ImageFilter.UnsharpMask(radius=0.6, percent=args.unsharp, threshold=1))

    im.save(args.output, "PNG")
    print(f"Saved {args.output}")

    # quick report
    im2 = Image.open(args.output).convert("RGBA")
    aa = [p[3] for p in im2.getdata()]
    print(f"  alpha range {min(aa)}-{max(aa)}, transparent pixels: {sum(x<255 for x in aa)}")

if __name__ == "__main__":
    main()
