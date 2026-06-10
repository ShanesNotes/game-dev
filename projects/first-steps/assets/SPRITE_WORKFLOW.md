# Sprite Workflow — AI art → Godot-ready sheets

How every sprite in `assets/` is made. The pattern: generate big, downscale
small, keep both.

## The pipeline

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

## Current assets

| Asset | Source | Notes |
|---|---|---|
| `character.png` | `character_source_1024.png` | 4×4 walk frames, 32px |
| `wolf.png` | `wolf_source.png` | single frame |
| `sword.png` | `sword_source.png` | pickup + held sprite |
| `tree.png` | `tree_source.png` | forest generator prop |
| `tileset.png` | — (hand-made) | 4 ground tiles: grass, dirt, stone, grass variant |
