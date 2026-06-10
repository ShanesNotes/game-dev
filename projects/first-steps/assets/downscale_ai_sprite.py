#!/usr/bin/env python3
"""
AI Sprite -> Godot ready downscaler + bg fixer.
Usage:
  python downscale_ai.py my_highres_char.png 128 128 out.png
  python downscale_ai.py sheet.png 32 32 --tile  --key-thresh 240

Good for taking Grok Imagine (or other AI) output and making clean 32px/frame sheets.
Requires Pillow.
"""
from PIL import Image, ImageEnhance, ImageFilter
import sys, argparse

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
