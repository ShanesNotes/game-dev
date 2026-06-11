# AI-Generated 2D Game Sprites — Reference Pipeline (mid-2026)

**Purpose:** single source of truth for how to generate, post-process, and import AI-made
sprites, sprite sheets, and tilesets into this Godot project. Covers hosted tools, local
open-source routes, the hard consistency problem, and concrete pipeline recommendations
keyed to the existing `downscale_ai_sprite.py` script and 32 px grid convention.

> **How to read this:** **Recommended** = tested/reviewed and broadly trusted by the
> community. **⚠** = claim is uncertain, sources conflict, or we couldn't independently
> verify it — don't treat it as settled. Every tool claim has a URL; if you're re-checking
> pricing, click through rather than trusting the cached figure here. Target: Godot 4, 32 px
> tiles/frames, hobbyist solo dev, no GPU server assumed for open-source routes.

Research conducted June 2026. Prices are in USD and change frequently — ⚠ always verify.

---

## §1 The Landscape — Hosted Tools

### Comparison table

| Tool | Best for | Animation / sheets | Tilesets | Price (approx.) | Source |
|---|---|---|---|---|---|
| **PixelLab** | Full pixel-art workflow: single sprites, sheets, tilesets, UI | Yes — walk/run/attack via skeleton or text prompt; up to 16 frames at 32×32, 4 frames at 128×128 per request | Yes — map/tileset generator, seamless tile mode | Free (5 slow gen/day, ≤200×200); $12/mo Apprentice (≤320×320); $50/mo Architect | [pixellab.ai](https://www.pixellab.ai/) |
| **Retro Diffusion** | Authentic, style-consistent single sprites; great palette control | Partial — "Walking & Idle", "Four Angle Walking", "Visual Effects" animation model sets | No dedicated tileset mode | Website: free with 50 credits; Aseprite plugin: one-time $65 (no sub) | [retrodiffusion.ai](https://retrodiffusion.ai/) |
| **Scenario** | Style-locked batch production; custom model training on your art | Via video-frame pipeline (not native frame-by-frame) | Yes — "tileable" toggle joins seams | Free 50 credits; Pro ≈$45/mo (5 000 compute units); Max ≈$75/mo | [scenario.com](https://www.scenario.com/) |
| **AutoSprite** | Walk/run/attack/idle sheets from a single upload; engine-ready JSON atlas | Yes — core feature, 20+ animation presets; consistent character across frames | No | Free 15 credits/mo; Starter $12/mo; Pro $29/mo | [autosprite.io](https://www.autosprite.io/) |
| **Layer.ai** | Studio-scale consistent sprite libraries; custom style encoding | Yes — idle/walk/run/attack multi-frame strips | Yes (atlas-ready export) | Usage-based; free trial available | [layer.ai](https://www.layer.ai/) |

#### Notes

**PixelLab** has the largest active user base among dedicated pixel-art AI generators
(reported 334 K–595 K monthly visits as of early 2026). The Aseprite plugin integrates
directly with the industry-standard editor. Animation tools cap at 128×128 px, which is
fine for this project's 32 px convention. Source: [pixellab.ai](https://www.pixellab.ai/),
[review Dec 2025](https://www.jonathanyu.xyz/2025/12/31/pixellab-review-the-best-ai-tool-for-2d-pixel-art-games/),
[sprite-ai comparison 2026](https://www.sprite-ai.art/blog/best-pixel-art-generators-2026).

**Retro Diffusion** was trained primarily on the creator's own artwork and consented
contributions — an ethical training-data distinction worth noting for commercial projects.
The Aseprite plugin is a one-time flat purchase with no subscription. The animation model
sets ("Four Angle Walking" in particular) are the most relevant feature for walk cycles.
Source: [retrodiffusion.ai](https://retrodiffusion.ai/),
[Runware overview](https://runware.ai/blog/retro-diffusion-creating-authentic-pixel-art-with-ai-at-scale),
[Gumroad plugin](https://astropulse.gumroad.com/l/RetroDiffusion).

**Scenario** shines when you have 10–50 reference images to train a custom character model
(30–60 min training, then every generation inherits the visual DNA). Not primarily a
pixel-art tool — works at any resolution, so output needs post-processing to feel like pixel
art. Source: [scenario.com/blog/ai-sprite-generator](https://www.scenario.com/blog/ai-sprite-generator),
[pricing](https://www.scenario.com/pricing).

**AutoSprite** is the most automated walk-cycle option: upload one sprite image, select
animation types, receive a grid-formatted PNG + JSON atlas. Claimed consistency across
frames; ⚠ independent third-party benchmarks are sparse — treat the "94% frame
consistency" figure in some marketing copy with scepticism until verified.
Source: [autosprite.io](https://www.autosprite.io/),
[AlternativeTo listing](https://alternativeto.net/software/autosprite/about/).

**Layer.ai** added Kling 2.5, Wan 2.5, and Seedream 4 models in 2026 — primarily useful for
the video-model extraction route described in §3. Source:
[layer.ai/blog/new-models-kling-wan-ray-seedream](https://www.layer.ai/blog/new-models-kling-wan-ray-seedream).

---

## §2 Open-Source Pipelines

### Stable Diffusion / SDXL checkpoints for pixel art

| Model | Base | What it does | Where |
|---|---|---|---|
| **Pixel Art Diffusion XL (Sprite Shaper)** | SDXL | Primary objective: pixel art at highest SDXL capability; sprite-focused | [civitai.com/models/277680](https://civitai.com/models/277680/pixel-art-diffusion-xl) |
| **SD_PixelArt_SpriteSheet_Generator** | SD 1.x | Generates 4-angle sprite sheets from prompts | [huggingface.co/Onodofthenorth/SD_PixelArt_SpriteSheet_Generator](https://huggingface.co/Onodofthenorth/SD_PixelArt_SpriteSheet_Generator) |
| **Pixel Art Sprite Diffusion v1** | SD 1.x | Original fine-tune; older but widely referenced | [civitai.com/models/22](https://civitai.com/models/22/pixel-art-sprite-diffusion) |

### Flux LoRAs for pixel art (2025–2026)

Flux.1-dev has become the preferred open base for pixel art LoRAs because of its strong
prompt fidelity and cleaner line rendering compared to SDXL.

| LoRA | Notes | Where |
|---|---|---|
| **Pixel Art Spritesheet – 4-Walk Small** | Explicitly for 32×32 walk-up/down/left/right + jump/lie frames; most directly relevant to this project | [civitai.com/models/2356302](https://civitai.com/models/2356302/pixel-art-spritesheet-4-walk-small) |
| **UmeAiRT/FLUX.1-dev-LoRA-Modern_Pixel_art** | Modern game pixel art style | [huggingface.co/UmeAiRT/FLUX.1-dev-LoRA-Modern_Pixel_art](https://huggingface.co/UmeAiRT/FLUX.1-dev-LoRA-Modern_Pixel_art) |
| **Retro-Pixel-Flux-LoRA** | Retro / console aesthetic | [huggingface.co/prithivMLmods/Retro-Pixel-Flux-LoRA](https://huggingface.co/prithivMLmods/Retro-Pixel-Flux-LoRA) |
| **Pixel Art & Video Game Graphics (Civitai)** | Broad game-style coverage | [civitai.com/models/816360](https://civitai.com/models/816360/pixel-art-and-video-game-graphics-lora) |

⚠ Civitai model availability fluctuates. Star/download counts not reproduced here because
they change daily — check the page.

### ComfyUI workflows

ComfyUI is the recommended local front-end for chaining SD/Flux models with
post-processing. Key workflow pattern for clean sprite sheets
([comfy.org template](https://comfy.org/workflows/templates-sprite_sheet-fe5600667e2c/),
[Apatero guide 2025](https://apatero.com/blog/generate-clean-spritesheets-comfyui-guide-2025)):

1. **Character LoRA** for per-character consistency.
2. **Prompt-per-pose** batch: generate all poses as one batch with a structured prompt per
   frame; slight seed variation between frames.
3. **ControlNet OpenPose** skeleton inputs force exact pose sequences for animation frames —
   especially important for walk cycles. Inject explicit palette instructions in prompts
   rather than vague style tokens ("retro colors" triggers uncontrolled model interpolation).
4. **Background removal node** (rembg or ComfyUI-native equivalent).
5. **Image Grid node** assembles individual frame images into a sprite sheet PNG.
6. Downsample to target sprite size *after* generating at a higher resolution; enforce
   palette quantization at the final low resolution.

Source: [kokutech.com ComfyUI+PixelArtXL guide](https://www.kokutech.com/blog/gamedev/tips/art/pixel-art-generation-with-comfyui),
[inzaniak.github.io pixel art ComfyUI guide](https://inzaniak.github.io/blog/articles/the-pixel-art-comfyui-workflow-guide.html).

### Background removal

**rembg** — 23.3 K GitHub stars, last release v2.0.76 June 3 2026 (actively maintained).
Supports 15+ models including `u2net` (general), `isnet-anime` (anime/cartoon characters),
`birefnet-general` (high-quality matting). CLI: `rembg i input.png output.png`.
Python: `pip install "rembg[cpu,cli]"`.
Source: [github.com/danielgatis/rembg](https://github.com/danielgatis/rembg).

For **pixel art on a solid white background** (like this project's current convention),
the existing color-key approach in `downscale_ai_sprite.py` is sufficient and faster
than running a neural matting model. Use rembg's `isnet-anime` only when the background
is complex or the character has fine hair/thin details that white-keying destroys.

### Palette quantization and post-processing

**Pillow `Image.quantize(colors=N)`** — built into the existing dependency. Reduces to up
to N colors using median-cut or libimagequant (Pillow 9+).
Source: [pillow.readthedocs.io](https://pillow.readthedocs.io/en/stable/reference/Image.html).

**hitherdither** — Pillow extension adding ordered dithering and error-diffusion algorithms
for arbitrary palettes; useful if you want a strict NES/Game Boy palette with proper
dithering.
Source: [github.com/hbldh/hitherdither](https://github.com/hbldh/hitherdither).

**PixelRefiner** — browser-based tool (TypeScript/Vite, runs offline as PWA); features
anti-aliasing removal, Oklab-space palette quantization, auto-transparency, grid detection,
batch ZIP export. 18 stars, last release v0.10.0 March 2026.
Source: [github.com/HappyOnigiri/PixelRefiner](https://github.com/HappyOnigiri/PixelRefiner).

**Pixel-Extractor** — browser-based (Pyodide/React/TypeScript); auto-detects pixel grid,
splits multi-sprite images, K-Means/histogram quantization, background removal. 20 stars.
Source: [github.com/univeous/Pixel-Extractor](https://github.com/univeous/Pixel-Extractor).

---

## §3 Animation-Frame Consistency — What Works, What Doesn't

Frame-to-frame consistency is the central unsolved problem in AI sprite generation. No
approach is fully reliable without some manual cleanup. Be honest about this.

### What actually works (well enough to use)

**1. Whole-sheet generation in one image — best for simple walk cycles**
Generate the entire sprite sheet as a single image using a model or LoRA trained to output
a grid layout (e.g., `SD_PixelArt_SpriteSheet_Generator`,
`Pixel Art Spritesheet – 4-Walk Small` Flux LoRA, or PixelLab's dedicated animation
tool). Because the same generation pass produces all frames, color palette and character
silhouette are consistent by construction. Works well at 32×32 where detail is low.
Source: [huggingface.co/Onodofthenorth/SD_PixelArt_SpriteSheet_Generator](https://huggingface.co/Onodofthenorth/SD_PixelArt_SpriteSheet_Generator),
[civitai.com/models/2356302](https://civitai.com/models/2356302/pixel-art-spritesheet-4-walk-small).

**2. PixelLab's animation-to-animation tool**
Upload a reference frame; specify action and frame count; PixelLab preserves that frame as
frame 0 and generates the remaining frames using it as an anchor. User reports from early
2026 note "some manual cleanup needed" but the character stays on-model across frames
better than per-frame img2img. Max 16 frames at 32×32 px per request.
Source: [pixellab.ai/docs/tools/animation-to-animation](https://www.pixellab.ai/docs/tools/animation-to-animation),
[review Dec 2025](https://www.jonathanyu.xyz/2025/12/31/pixellab-review-the-best-ai-tool-for-2d-pixel-art-games/).

**3. Retro Diffusion "Four Angle Walking" / "Walking & Idle" model sets**
Specialized fine-tuned variants that output directional walk poses; palette is locked to
your custom upload or chosen style. Integrates with Aseprite for rapid iteration.
Source: [retrodiffusion.ai](https://retrodiffusion.ai/),
[Runware explainer](https://runware.ai/blog/retro-diffusion-creating-authentic-pixel-art-with-ai-at-scale).

**4. ControlNet OpenPose + character LoRA in ComfyUI**
Draw or procedurally generate a skeleton sequence for each frame; feed each skeleton as
a ControlNet conditioning input while keeping the character LoRA active. This enforces
limb positions across frames. ⚠ Requires hand-crafting or scripting the skeleton sequence,
which is non-trivial; works best for hobbyists comfortable in ComfyUI.
Source: [Apatero ComfyUI guide 2025](https://apatero.com/blog/generate-clean-spritesheets-comfyui-guide-2025),
[Civitai Sprite Sheet Maker workflow](https://civitai.com/models/448101/sprite-sheet-maker).

**5. Video-model extraction (emerging, 2025–2026)**
Generate short character animation clips with a video model (Wan 2.2 I2V with pixel-art
LoRA, Kling 2.5, or Seedream 4), then extract frames with FFmpeg and key the background.
A Wan 2.2 pixel-animation LoRA exists specifically for this:
[huggingface.co/styly-agents/Wan2-2-pixel-animate](https://huggingface.co/styly-agents/Wan2-2-pixel-animate).
A Wan 2.1 sprites generator workflow is on Civitai:
[civitai.com/models/1706955/wan21-sprites-generator](https://civitai.com/models/1706955/wan21-sprites-generator).
Layer.ai integrated Kling 2.5 and Wan 2.5 in 2026.
⚠ Quality is variable — video models bias toward cinematic camera motion, not the
"centred, static background" requirement of a sprite sheet. Extracted frames need heavy
cleanup. This approach is experimental for hobbyist use.

### What doesn't work well

**Per-frame img2img with no reference lock** produces drifting character shapes, shifting
palettes, and inconsistent shading between frames — even at modest denoising strengths.
The SD 1.x community workaround of "generate best frame, mirror for opposite direction"
is still necessary for SD-based pipelines.
Source: [replicate.com/cjwbw/sd_pixelart_spritesheet_generator](https://replicate.com/cjwbw/sd_pixelart_spritesheet_generator).

**Research direction (not production-ready):** A 2024 arxiv paper (arXiv:2412.03685)
proposes a dedicated sprite sheet diffusion system using ReferenceNet spatial attention +
a Pose Guider + a temporal motion module to enforce cross-frame consistency. The approach
is promising but not packaged as a usable tool as of mid-2026.
Source: [arxiv.org/html/2412.03685v1](https://arxiv.org/html/2412.03685v1).

⚠ **Honest bottom line:** Every current method requires at least one manual cleanup pass
on animation frames. Expect to spend 10–30 minutes in Aseprite or similar per animation,
regardless of which AI tool generates the raw frames. At 32 px, small inconsistencies are
often invisible in-game — which is a practical advantage of working small.

---

## §4 Post-Processing — The Downscale / Key / Quantize Toolchain

### Resolution strategy: generate big and downscale vs. native pixel size

**Native pixel size generation (e.g., 32×32 directly)** produces true pixel art — every
pixel is intentional, lines are crisp, no anti-aliasing to clean up. Dedicated tools like
PixelLab, Retro Diffusion, and the `SD_PixelArt_SpriteSheet_Generator` checkpoint generate
natively at game resolution. This is the highest-quality route.

**Generate big, downscale** (this project's current approach) produces "pixel-styled"
illustration art rather than true pixel art, because the AI places anti-aliased, blended
pixels at the source resolution. The downscale creates a passable result but always leaves
anti-aliased fringe and muddy colour at pixel boundaries.
⚠ Source [sprite-ai.art image-to-pixel-art comparison](https://www.sprite-ai.art/blog/image-to-pixel-art-converter)
argues native generation is strictly better; the existing pipeline's SPRITE_WORKFLOW.md
acknowledges the fringe problem explicitly.

**Practical conclusion for this project:** Keep the generate-big / downscale pipeline for
single sprites where artistic quality matters less (props, items, tiles). Switch to a
native-generation tool (PixelLab at 32×32 or the Flux walk-cycle LoRA) for anything
animated where frame consistency is critical.

### Downscaling filter choice

**Lanczos** (current): best for single-step big-to-small reduction; preserves high-
frequency information better than bilinear while avoiding the staircasing of nearest
neighbor. Correct choice when going from, e.g., 512 px source → 32 px game sprite in one
step. Source: [Wikipedia image scaling](https://en.wikipedia.org/wiki/Image_scaling),
[Pillow docs](https://pillow.readthedocs.io/en/stable/reference/Image.html).

**Nearest-neighbor** (`Image.NEAREST`): correct *only* when the source is already true
pixel art (integer multiples of the target grid, deliberate pixel placement). Using
nearest-neighbor on a painterly AI source destroys detail unpredictably. Add a
`--nearest` flag to `downscale_ai_sprite.py` for use with PixelLab/Retro Diffusion output
that is already at pixel-art resolution and just needs an integer scale.

### White-key vs. rembg matting

| Situation | Recommended approach |
|---|---|
| Solid white background (this project's convention) | White key (`--key-thresh 242`); fast, no model dependency |
| Anti-aliased fringe surviving the key | Lower `--key-thresh` incrementally (240, 238…) |
| Complex or gradient background | rembg `isnet-anime` model |
| Fine hair / antenna / thin outline | rembg `birefnet-general` model |

The current `downscale_ai_sprite.py` white-key is appropriate for its use case.

### Palette quantization

Pillow's `Image.quantize(colors=N)` reduces the palette after downscaling. Recommended
to add as an optional `--palette N` flag to `downscale_ai_sprite.py`. Quantize *after*
background removal and *after* downscaling — at 32×32 the colour reduction noise is
smallest. Suggested values: 16 for NES-feel, 32–64 for general retro.
Source: [Pillow quantize docs](https://pillow.readthedocs.io/en/stable/reference/Image.html),
[bomberbot.com Pillow quantize guide](https://www.bomberbot.com/python/unlocking-the-power-of-python-pils-image-quantize-method/).

For dithered palette reduction to a specific retro palette (NES, GB, etc.) use hitherdither
on top of Pillow:
[github.com/hbldh/hitherdither](https://github.com/hbldh/hitherdither).

### Cleaning anti-aliased edge fringe

After white-keying, semi-transparent edge pixels remain around anti-aliased outlines.
Options in ascending effort:
1. Lower `--key-thresh` until fringe disappears (risks eating into the sprite's own light colours).
2. PixelRefiner browser tool: "anti-aliasing removal" snaps semi-transparent edge pixels
   to fully opaque or fully transparent via alpha threshold.
   [github.com/HappyOnigiri/PixelRefiner](https://github.com/HappyOnigiri/PixelRefiner).
3. Manual cleanup in Aseprite (always necessary for animation-quality assets).

---

## §5 Recommended Pipeline for This Repo

### Keep and extend `downscale_ai_sprite.py`

Current behaviour is correct for single sprites and tilesets generated at high resolution.
Worthwhile additions:

**Add `--nearest` flag** (no-op by default; switches `Image.LANCZOS` to `Image.NEAREST`):
```python
resample = Image.NEAREST if args.nearest else Image.LANCZOS
im = im.resize((args.width, args.height), resample)
```
Use this when the source is already pixel art from PixelLab or Retro Diffusion.

**Add `--palette N` flag** (runs after the key step):
```python
if args.palette:
    im = im.quantize(colors=args.palette, method=Image.Quantize.MEDIANCUT).convert("RGBA")
```
Suggested default: disabled. Invoke with `--palette 32` for retro-feel assets.

**Add `--grid WxH` validation flag** — after processing, assert that the output dimensions
are divisible by the given tile/frame size and print an ASCII grid preview so you can
catch off-by-one slicing errors before import:
```python
if args.grid:
    fw, fh = map(int, args.grid.split('x'))
    assert args.width % fw == 0 and args.height % fh == 0, "Output not aligned to grid"
    print(f"Grid: {args.width//fw} cols × {args.height//fh} rows of {fw}×{fh} px")
```
Example: `--grid 32x32` on a 128×32 output confirms 4 frames.

### For walk-cycle sheets — try PixelLab first

1. In PixelLab, generate or upload a single 32×32 (or 64×64 for more detail) character frame.
2. Use the **animation-to-animation** tool; pick "walk" action, 4 or 8 frames. Keep source
   resolution at 32×32 or 64×64.
3. Download the sprite sheet PNG (PixelLab exports the whole sheet as one image).
4. If generated at 64×64: run through `downscale_ai_sprite.py` with `--nearest` (source
   is already pixel art) to halve to 32×32. If already 32×32: skip `downscale_ai_sprite.py`
   entirely or run with `--nearest` just for the key and palette steps.
5. Validate with `--grid 32x32`.

**Fall-back for hobbyist local route:** Flux LoRA
[Pixel Art Spritesheet – 4-Walk Small](https://civitai.com/models/2356302/pixel-art-spritesheet-4-walk-small)
in ComfyUI, ControlNet OpenPose for pose sequencing, rembg for BG removal.

**For tilesets:** PixelLab's map/tileset generator with "seamless" mode; alternatively,
Retro Diffusion with "tiling" enabled generates single tiles you assemble manually.
Keep exporting to `<name>_source.png` → run `downscale_ai_sprite.py` → `<name>.png`.

### What to standardise on

- **Source files:** always keep `<name>_source.png` in the repo. Non-negotiable.
- **Grid:** 32 px tiles/frames remain the convention.
- **Background generation:** white background stays as the convention for most sources
  (simplest keying). Switch to transparent-background generation only if the tool
  supports it natively (PixelLab exports transparent PNGs directly).
- **Import:** keep lossless compression (Godot default for PNG). No change needed.
- **Godot project setting:** confirm `Project Settings → Rendering → Textures → Canvas
  Textures → Default Texture Filter` is set to **Nearest** (if not already set).
  Source: [GDQuest pixel art setup](https://www.gdquest.com/library/pixel_art_setup_godot4/),
  [Godot 4.4 import docs](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_images.html).
- **SpriteFrames slicing:** AnimatedSprite2D → SpriteFrames editor → "Add frames from
  Sprite Sheet" → set H/V frame counts → select frames. Keep sheets at power-of-two
  dimensions when possible (256×32, 128×32 etc.).
  Source: [Godot forum sprite sheet slicer](https://forum.godotengine.org/t/how-do-i-use-the-sprite-sheet-slicer-in-godot4/43407).
- **TileSet atlas:** TileSet resource → atlas setup → set Texture Region Size to 32×32;
  add Separation (padding) if seam artifacts appear.

---

## §6 Open Questions / Re-check Later

1. **PixelLab credit costs for animation tool** — the FAQ page was inaccessible during
   research. The $12/mo plan reportedly caps at 320×320 px output; ⚠ verify that 32×32
   animation generation is within the free tier before committing.
   Re-check: [pixellab.ai/docs/faq](https://www.pixellab.ai/docs/faq).

2. **AutoSprite frame-consistency claims** — "94% frame-to-frame consistency" appears in
   some marketing; no independent technical benchmark found. Try a free-tier walk cycle on
   an existing project character and evaluate visually before paying.
   Source: [autosprite.io](https://www.autosprite.io/).

3. **Wan 2.2 pixel-animate LoRA quality** — the
   [styly-agents/Wan2-2-pixel-animate](https://huggingface.co/styly-agents/Wan2-2-pixel-animate)
   LoRA is recent (2026); community evaluation is sparse. The video-model approach is
   promising but cleanup burden is unquantified. Re-evaluate when community examples accumulate.

4. **arXiv:2412.03685 "Sprite Sheet Diffusion"** — research paper proposing ReferenceNet +
   Pose Guider + temporal module for consistent multi-frame generation. Not yet packaged
   as a usable tool as of June 2026. Watch for a public release.
   Source: [arxiv.org/html/2412.03685v1](https://arxiv.org/html/2412.03685v1).

5. **Native 32×32 Flux LoRA output quality** — the
   [Pixel Art Spritesheet – 4-Walk Small](https://civitai.com/models/2356302/pixel-art-spritesheet-4-walk-small)
   LoRA targets 32×32 natively. Test against PixelLab's animation output to decide
   whether local generation reaches hosted-tool quality for this project's art style.

6. **rembg vs. white-key for this project's specific art** — rembg adds a Python/ONNX
   dependency. Run a comparison on `character_source_1024.png` with `isnet-anime` vs.
   the current white-key to check whether matting quality justifies the dependency.

7. **Scenario pricing restructure** — Scenario's compute-unit model changes frequently.
   ⚠ The figures above ($45/mo Pro, $75/mo Max) should be verified before purchase.
   [scenario.com/pricing](https://www.scenario.com/pricing).

---

*Last updated: June 2026. Research via web search; several tool home pages returned HTTP
403 and could not be directly fetched — information sourced from search result summaries,
third-party reviews, and accessible secondary sources. Treat ⚠-flagged items accordingly.*
