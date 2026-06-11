# Sprite Workflow — AI art → Godot-ready sheets

How every sprite in `assets/` is made. Two routes, one script. The full
research behind these choices (tools, prices, what's still unsolved) lives in
[`reference/ai-asset-pipeline.md`](../../../reference/ai-asset-pipeline.md).

- **Route A — generate big, downscale** (how everything here so far was made):
  any AI image tool → high-res on white → the script below. Good for single
  sprites, props, and tiles.
- **Route B — generate at native pixel resolution** (better for animation
  sheets): a dedicated pixel-art tool (PixelLab, Retro Diffusion) outputs real
  32px art → run the script with `--nearest` (no resharpening, no Lanczos
  smear). Frame-to-frame consistency is the unsolved problem of AI sprites;
  whole-sheet generation in one pass beats stitching frames.

## The pipeline (Route A)

1. **Generate high-res** with an AI image tool (Grok Imagine has worked well).
   Prompt for: a single subject (or a clean grid for sheets), **flat white
   background**, no drop shadow, centred. Save it here as `<name>_source.png`
   (e.g. `character_source_1024.png`) — the source stays in the repo so art can
   be re-derived or re-cut later.
2. **Downscale + clean** with the script in this folder:

   ```
   python downscale_ai_sprite.py character_source_1024.png 128 32 character.png
   ```

   Positional args: `input width height output` (target size in pixels —
   `128 32` = a 4-frame 32px strip). What it does, in order:
   - Lanczos resize to the target size
   - keys near-white pixels (`--key-thresh`, default 242) to transparent
   - restores punch lost in the resize: `--contrast` (1.25), `--sat` (1.2),
     unsharp mask (`--unsharp` 130)
   - prints an alpha report so you can confirm the background actually keyed

   Optional flags: `--palette 32` quantizes stray AI colors into a unified
   palette; `--grid 32x32` fails loudly if an animation sheet doesn't slice
   into whole frames; `--nearest` switches to Route B behaviour (nearest-
   neighbor resize, no resharpening — for sources that are already pixel art).
3. **Drop the output PNG in `assets/`** — Godot picks it up and writes the
   `.import` file automatically. Lossless compression (the default) is correct
   for these; no import settings need changing.
4. **Wire it in the editor** — for animation sheets, slice in SpriteFrames
   (32×32 regions, as in Lesson 7); for tiles, slice in the TileSet atlas
   (Lesson 5).

## Conventions

- Game-resolution art is **32px per tile/frame**.
- `<name>_source.png` = high-res AI original; `<name>.png` = the game asset.
  Never edit the game asset by hand — re-run the script from source.
- If edges look haloed, the white key missed anti-aliased fringe: lower
  `--key-thresh` a notch (240, 238, …) and re-run.
- For crisp pixel art at game scale, set Godot's
  **Project Settings → Rendering → Textures → Canvas Textures → Default
  Texture Filter → Nearest** (per-texture override: CanvasItem → Texture →
  Filter). Linear filtering is why pixel art looks blurry.

## Current assets

| Asset | Source | Notes |
|---|---|---|
| `character.png` | `character_source_1024.png` | 4×4 walk frames, 32px |
| `wolf.png` | `wolf_source.png` | single frame |
| `sword.png` | `sword_source.png` | pickup + held sprite |
| `tree.png` | `tree_source.png` | forest generator prop |
| `tileset.png` | — (hand-made) | 4 ground tiles: grass, dirt, stone, grass variant |
