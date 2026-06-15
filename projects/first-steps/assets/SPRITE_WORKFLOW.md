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

## Current asset generators

All generator scripts anchor paths to this folder, so they can be run either from
`projects/first-steps/assets/` or from the repository root. Generated previews go
to `/tmp/`; committed game assets stay beside the scripts.

Recommended full rebuild order:

1. `python gen_terrain.py` → `terrain.png` (the current Ground/Road atlas).
2. `python gen_props.py` → trees, bushes, rocks, stump, mushrooms, campfire, signpost.
3. `python gen_creatures.py` → `character_clean.png`, `wolf_sheet.png`, `sword_clean.png`, portrait.
4. `python gen_polish.py` → mutates the creature/UI outputs in place and bakes the held/swing sword frames. Run it after `gen_creatures.py`.
5. `python gen_pickup.py` → pedestal, glint, icon.
6. `python gen_uifx.py` → HUD chrome, VFX textures, target/aggro marks.
7. `python gen_sfx.py` → deterministic WAVs under `sounds/`.

Legacy lesson assets (`tileset.png`, `tree.png`, `character.png`, `wolf.png`,
`sword.png`) remain in the repo because early lessons still reference the build
ramp. The current playable world uses the generated v2 assets listed above.

## Current source assets

| Asset | Source | Notes |
|---|---|---|
| `character.png` | `character_source_1024.png` | early/AI source sheet; `gen_creatures.py` produces `character_clean.png` |
| `wolf.png` | `wolf_source.png` | early source; `gen_creatures.py` produces `wolf_sheet.png` |
| `sword.png` | `sword_source.png` | early source; `gen_creatures.py` + `gen_polish.py` produce final sword frames |
| `terrain.png` | `gen_terrain.py` | current 4×6 atlas for Ground + Road |
| `tileset.png` | `make_tileset.py` | legacy four-tile lesson ramp asset |
