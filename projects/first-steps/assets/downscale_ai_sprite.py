#!/usr/bin/env python3
"""
AI sprite -> Godot-ready downscaler + background keyer.

Usage:
  python downscale_ai_sprite.py character_source_1024.png 128 32 character.png
  python downscale_ai_sprite.py wolf_source.png 32 32 wolf.png --key-thresh 240
  python downscale_ai_sprite.py sheet.png 128 32 out.png --grid 32x32 --palette 32
  python downscale_ai_sprite.py pixellab_out.png 32 32 wolf.png --nearest

Takes AI output and makes a clean game asset:
  - resizes to the target sheet size (Lanczos for high-res sources; --nearest
    for sources already at pixel-art resolution, e.g. PixelLab/Retro Diffusion)
  - keys the near-white background to transparency (--key-thresh)
  - restores contrast/saturation/sharpness lost in a big->small resize
    (skipped automatically with --nearest: real pixel art must not be resharpened)
  - optionally quantizes to a fixed palette (--palette N) for a unified look
  - optionally validates frame alignment (--grid WxH) for animation sheets

See SPRITE_WORKFLOW.md here and reference/ai-asset-pipeline.md at the repo root.
Requires Pillow.
"""
from PIL import Image, ImageEnhance, ImageFilter
import argparse
import sys

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("width", type=int)
    ap.add_argument("height", type=int)
    ap.add_argument("output")
    ap.add_argument("--key-thresh", type=int, default=242, help="RGB value above which is treated as bg white to key out (256 disables)")
    ap.add_argument("--contrast", type=float, default=1.25)
    ap.add_argument("--sat", type=float, default=1.2)
    ap.add_argument("--unsharp", type=float, default=130)
    ap.add_argument("--nearest", action="store_true", help="nearest-neighbor resize + no resharpening (for native pixel-art sources)")
    ap.add_argument("--palette", type=int, default=0, help="quantize to N colors after processing (0 = off)")
    ap.add_argument("--grid", default=None, help="frame size WxH (e.g. 32x32); validates the sheet slices into whole frames")
    args = ap.parse_args()

    im = Image.open(args.input).convert("RGBA")
    print(f"Loaded {im.size} -> target {args.width}x{args.height}")

    resample = Image.NEAREST if args.nearest else Image.LANCZOS
    im = im.resize((args.width, args.height), resample)

    # White key
    datas = im.getdata()
    newd = []
    t = args.key_thresh
    for r, g, b, a in datas:
        if r > t and g > t and b > t:
            newd.append((255, 255, 255, 0))
        else:
            newd.append((r, g, b, a))
    im.putdata(newd)

    # Recover pop lost in a Lanczos downscale. Never resharpen real pixel art.
    if not args.nearest:
        im = ImageEnhance.Contrast(im).enhance(args.contrast)
        im = ImageEnhance.Color(im).enhance(args.sat)
        im = im.filter(ImageFilter.UnsharpMask(radius=0.6, percent=args.unsharp, threshold=1))

    # Optional palette lock: quantize unifies stray AI colors into N flats.
    if args.palette > 0:
        im = im.quantize(colors=args.palette, method=Image.Quantize.FASTOCTREE).convert("RGBA")
        print(f"  quantized to <= {args.palette} colors")

    im.save(args.output, "PNG")
    print(f"Saved {args.output}")

    # quick report
    im2 = Image.open(args.output).convert("RGBA")
    aa = [p[3] for p in im2.getdata()]
    print(f"  alpha range {min(aa)}-{max(aa)}, transparent pixels: {sum(x < 255 for x in aa)}")

    # Frame-grid validation for animation sheets / tile atlases
    if args.grid:
        try:
            gw, gh = (int(v) for v in args.grid.lower().split("x"))
        except ValueError:
            sys.exit(f"--grid expects WxH, e.g. 32x32 (got {args.grid!r})")
        if args.width % gw or args.height % gh:
            sys.exit(f"GRID FAIL: {args.width}x{args.height} does not slice into whole "
                     f"{gw}x{gh} frames -- Godot's atlas will cut frames mid-pixel.")
        print(f"  grid ok: {args.width // gw}x{args.height // gh} frames of {gw}x{gh}")

if __name__ == "__main__":
    main()
