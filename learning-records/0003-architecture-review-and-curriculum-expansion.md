# 0003 — Architecture review & curriculum expansion (the overhaul, reconciled)

**Date:** 2026-06-11 · status: **active record / Forge + Input bridge + G009/G010 passes complete** (remaining cleanup tracked by the Ultragoal)

## Context

Two working sessions on 2026-06-11, both Claude-driven at the user's request:

1. **Bugfix + controller:** movement was dead (stale `uid_cache.bin` mapped the player
   script's UID to its pre-rename path `sprite_2d.gd`, so the Player loaded with no
   script). Fixed; input actions formalized (`move_*`, `target_next`, `attack`) with
   keyboard + controller bindings.
2. **Full visual overhaul ("nothing sacred"):** every visual element replaced or rebuilt —
   procedural asset pipeline, dual-grid road, Y-sorted world, animated wolf, combat juice,
   WoW-style HUD — via parallel sprite-atelier agents and two screenshot-critique panels.

**Law-2 tension, named honestly:** a large system entered the repo without the learner
writing it. The precedent is lesson 26 (`forest_generator.gd` "entered the repo ahead of
its lesson" → got a retrofit lesson). This record is the plan for repaying that debt at
scale, plus the findings of an architecture review (`/improve-codebase-architecture`) run
immediately after.

This record is **canonical** for those findings; the visual report is attached as
[`0003-architecture-review.html`](0003-architecture-review.html).

## What entered the repo ahead of its lessons

Untaught systems now in the codebase (the retrofit inventory):

- **Input map v2** — `move_*` actions (WASD/arrows/stick/d-pad), `target_next` (Tab/RB),
  `attack` gains Space/right mouse/A-button. *(Forward-noted in L03; paid by L37.)*
- **Scene restructure** — `Main → {Ground, Road, World}`; actors live under a
  **Y-sorted `World`**; floor layers use negative `z_index`. Trees/props anchor their
  origin at the visual base so Y-sort layers them correctly.
- **Dual-grid road** — `terrain.png` atlas (grass/dirt variants + 3 banks of 16
  corner-bit transition tiles); `Road` TileMapLayer offset (−16,−16); radius-16
  corner-circle masks guarantee seamless joins; interior-only boundary roughening.
- **Forest generation v2** — grove clumping, roadside scatter pass, spawn-camp dressing
  (campfire + flickering glow, signpost, stump), map-edge walls, camera limits.
- **Wolf v2** — `AnimatedSprite2D` (idle/walk/attack), hit-flash, blood, death tween,
  aggro `!` mark, golden target ring (selection moved off modulate-tint).
- **Combat juice** — slash arc, hit sparks, crit screen-shake, footstep dust, pollen
  (all `CPUParticles2D` + tweens); damage numbers with pop-in scaling + pixel font.
- **HUD v2** — `UnitFrame` (portrait/name/HP/rage via `TextureProgressBar`),
  `TargetFrame`, controls hint strip, `hud.gd` (currently **polls** — see candidate 2),
  OFL pixel fonts (Press Start 2P, VT323).
- **Atmosphere** — warm `CanvasModulate`, dithered warm vignette, pixel-snap project
  setting, baked sword rest pose (`sword_held.png`, `SWORD_REST_DEGREES` now `0.0`).
- **Asset pipeline** — deterministic PIL generators in `assets/`: `gen_terrain.py`,
  `gen_props.py`, `gen_creatures.py`, `gen_uifx.py`, `gen_polish.py` (+ shared master
  palette by convention). **Order matters:** `gen_creatures.py` must run before
  `gen_polish.py` (polish mutates its outputs in place; not idempotent).

**Added by the UX/production-polish round (later on 2026-06-11):**

- **Sfx autoload** — `sfx.gd` sound bus (`play` / `play_at`), 13 synthesized WAVs from
  `gen_sfx.py` (deterministic, seam-rotated loops); ambience + campfire crackle live as
  scene nodes, not the bus. *(→ taught in L27.)*
- **Pickup moment** — pedestal prop, bob tween, glint particles, chime + gold burst +
  banner, deferred teardown; attacks gated on `has_sword` ("No weapon!" + hint banner)
  — the one mechanic-adjacent change, justified as making the pickup meaningful.
  *(→ taught in L28.)*
- **Directional held sword** — `update_sword_pose()` (right/left-mirrored/tucked-behind-up),
  mirrored swing arcs, `face_toward()`. *(→ taught in L29.)*
- **Swing feel** — lunge tween, crit hit-stop (`Engine.time_scale`), camera shake,
  outcome-laddered SFX volumes. *(→ taught in L30.)*
- **Death sequence** — dying guard, sting, fade, "— Memory Eternal —", 2.4 s respawn;
  HUD hurt flash + low-HP pulse. *(→ taught in L31.)*
- **HUD UX** — banner toasts (`show_banner`), tutorial hint chips that dim per learned
  action, tweened HP/target bars. *(banner taught in L28; chips taught in L32.)*
- **Window identity** — `config/name="Will's First Steps"`, generated `icon.png`
  (`gen_pickup.py`).

## Architecture findings (preserved for the attentive session)

Vocabulary: *module / interface / seam / depth / locality / leverage / deletion test*
(per the review skill). Each candidate names its Law-5 trigger.

### 1 · CombatTable — the attack table as a deep module · **Strong**
- **Files:** `player.gd:111–202`, `reference/wow-combat-values.md`.
- **Problem:** the seven researched formulas (miss/dodge/parry/glancing/crit/glancing-damage)
  + the one-roll band-walk + three rage conversions are pure math interleaved with node
  calls. The interface to "how combat resolves" is *all of player.gd*; the band ordering
  (`roll < miss + dodge + …`) is the exact bug habitat and is untestable headless.
- **Solution:** `combat_table.gd` (`class_name CombatTable`, static, zero nodes):
  `roll(attacker, defender, rng) → Outcome {kind, damage}` + `rage_from_dealing/taking`.
  `attack()` shrinks to: roll, then present. Citation moves to the file header.
- **Benefits:** first headless test seam in the repo
  (`godot --headless --script tests/test_combat_table.gd`, seeded RNG, assert exact
  reference values); locality for the whole upcoming combat arc; deletion test passes
  decisively. **Trigger: fired** — XP/abilities lessons extend exactly this code.

### 2 · Player announces, HUD listens — a signal seam · **Strong**
- **Files:** `player.gd:18,21` (hard paths *into* HUD layout), `hud.gd:16–27`
  (per-frame polling of `player.target` / `target.health`), `wolf.gd`.
- **Problem:** the Player's interface includes the HUD's internal layout
  (`../../HUD/UnitFrame/HealthBar`) — it already broke once when Player moved under
  `World`. The HUD polls every frame, **contradicting the curriculum's own L11 doctrine
  ("events over polling")**.
- **Solution:** Player emits `health_changed(v,max)`, `rage_changed(v)`,
  `target_changed(t)`; Wolf emits `health_changed`; HUD connects in `_ready()`, its
  `_process` deleted. Player stops knowing a HUD exists.
- **Benefits:** deletion test on HUD goes from "crashes Player" to "game runs headless";
  HUD/XP-bar changes never touch player.gd; it's L11 doctrine applied — a natural lesson.
  **Trigger: fired twice** (the breakage + the doctrine).

### 3 · CombatFX — one home for floating text & bursts · **Shipped**
- **Files:** `combat_fx.gd`, `player.gd`, `wolf.gd`, `sword.gd`, `tests/test_combat_fx.gd`.
- **Problem:** five near-duplicate spawners (`spawn_text_over`, `spawn_number` ×2,
  `spawn_sparks`, `spawn_blood`), each assuming scene-tree shape via
  `get_parent().add_child`.
- **Solution:** a `CombatFX` **autoload**: `text_over(target, words, color)`,
  `damage_number(target, amount, color, size)`, `sparks(at, color, count)`, and
  `blood(at)`, all spawning through one shared helper.
- **Benefits:** deletion-test pass; actors ask for feedback without owning construction;
  teaches **autoloads** again through a visual-feedback service (L36).

### 4 · ForestPlan — split the plan from the planting · **Parked (Law 5)**
- **Files:** `forest_generator.gd`.
- **Shape:** `ForestPlan.build(seed, w, h) → plan` (pure data: dirt mask, tiles, road
  bits, prop placements, spawns) + a thin node applier. Placement invariants become
  headless assertions; seed regressions become data diffs.
- **Why parked:** recent forest bugs were wiring, not planning logic; only one consumer
  of the plan exists. **Trigger to unpark:** the next real generation-logic bug, OR a
  second plan consumer (minimap, lesson visual, debug renderer).

### 5 · A lessons↔code contract (drift check) · **Strong, actively on fire**
- **Problem:** lessons anchor to code via prose snippets/names only; the overhaul
  silently contradicted ≥4 lessons (table below). The exhibit's promise — *the course is
  the codebase's build order* — is breakable by any refactor, and breakage is currently
  discovered by the learner mid-lesson.
- **Solution:** per-lesson **claims manifest** (~10 lines: input actions, node paths,
  asset files, named constants the snippets rely on) + one `check_lessons.py` validating
  claims against `project.godot`/scenes/assets. Drift becomes a failing check that names
  the lesson and the claim.
- **Anti-telos guard:** exhibit tooling in service of the mission — keep it one small
  script, not a project.

### Honored locked/parked decisions (not re-suggested)
- **WeaponData** Resource — parked at the inventory lesson until the second weapon
  exists (per 0002). Unchanged.
- **Collision layers stay unified** — locked, "do NOT re-suggest." Untouched.

## Drift inventory (consistency repairs)

| Lesson | Teaches | Code now | Note |
|---|---|---|---|
| 03 (input) | `Input.get_vector("ui_left", …)` | `move_left/right/up/down` | smallest repair |
| 05 (tilemap) | slice `assets/tileset.png` | `terrain.png` atlas + `Road` layer | biggest gap — likely an "evolution note," not a rewrite |
| 09 (wolf) | wolf sprite implicitly `$Sprite2D` | `$AnimatedSprite2D` | small |
| 13/15/16/25 (HUD/bars) | `get_node("../HUD/HealthBar")` | `../../HUD/UnitFrame/HealthBar` | **do not repair before the signals decision** — paths change again if candidate 2 ships; repair once |
| 17 (sword) | drag `assets/sword.png`; `SWORD_REST_DEGREES = 25.0` | `sword_held.png`; constant `= 0.0` (pose baked) | constant is taught by name |

Also affected conceptually: L07 (walk rows — now four true directions exist;
`walk_right` previously reused the left row, which the overhaul fixed).

## Curriculum expansion (proposed backlog — numbering decided later)

0002's sequence stays intact conceptually, but numbering slides after the retrofit arcs. Game Feel appended as L27–L32 and The Forge appended as L33–L36, preserving the actual build order.

### Arc "The Forge" — engineering the combat core *(STARTED 2026-06-14)*
One win each; all triggers fired. Numbered as **lessons 33–36** (append, per the v2
"course = build order" precedent; XP slides after). Built the Game-Feel way: code
refactored first, lesson back-engineered against final code.

- **F1 · The attack table becomes a module** — ✅ **shipped as L33.** Extracted
  `combat_table.gd` (`class_name CombatTable`): the 7 chance formulas + glancing band +
  rage, as pure static funcs, each citing `wow-combat-values.md`. `player.gd` rewired to
  call `CombatTable.*`; local formulas deleted (358→326 lines). Game boots clean, plays
  identically. Teaches `class_name`, static/pure funcs, the deletion test.
  *(Note: used `maxi()` not `max()` — typed `:=` + warnings-as-errors rejects Variant.)*
- **F2 · The first test** — ✅ **shipped as L34.** `tests/test_combat_table.gd` — a
  headless `SceneTree` script, 18 assertions vs the reference, exit-code verdict. Repo's
  first test; PASSes. Run: `godot --headless --path projects/first-steps --script
  res://tests/test_combat_table.gd`. Teaches headless `--script`, float tolerance, `quit()`.
- **F3 · Events over polling II — the HUD stops spying** — ✅ **shipped as L35.** Inverted
  *both* directions: `player.gd` declares 8 signals (`health_changed`, `rage_changed`, `hurt`,
  `died`, `target_changed`, `banner_requested`, `moved`, `attack_started`) and dropped all HUD
  refs; `wolf.gd` emits `health_changed`/`died`; `sword.gd` calls `body.announce()` not
  `body.hud.*`; `hud.gd` deleted `_process`, connects to player/target signals (deferred), and
  the low-health pulse became a looping tween that yields to the hit-flash. Verified: game boots
  clean 120 frames, HUD freed mid-run with no crash (delete-HUD win), combat test still green.
- **F4 · One home for combat FX** — ✅ **shipped as L36.** Added `combat_fx.gd` as a
  `CombatFX` autoload beside `Sfx`; moved floating text, damage numbers, sparks, and blood
  into one helper. `player.gd`, `wolf.gd`, and `sword.gd` now ask `CombatFX` instead of
  constructing feedback nodes locally; old spawner helpers deleted. Added
  `tests/test_combat_fx.gd` to prove the factories, and the boot check proves the autoload name.
  **The Forge is complete.**

### Arc VII "Game Feel" — **STARTED 2026-06-11** (the UX-round retrofits)

Per the user's directive ("back engineer your optimizations to loop them into our lesson
plans/guide"), the UX-round systems are being retrofitted as a new index arc, L26-style
(guided build of the real repo code + a tune-one-number exercise):

- **L27 · The Game Finds Its Voice: Autoloads & Sound** — ✅ shipped. Sfx bus, autoload
  concept (new to curriculum — partially covers candidate 3's teaching goal), signals
  connected in code, play/play_at lifetime contrast, loudness ladder.
- **L28 · Juice: The Pickup Moment** — ✅ shipped. Juice doctrine, looped tweens,
  toast pattern (kill-then-retween), `set_deferred`, polite teardown, attack gating.
- **L29 · Holding It Right** — ✅ shipped. `update_sword_pose` (position/flip_h/
  show_behind_parent), baked rest pose rationale (pixels live on a grid), `face_toward`,
  mirrored swing arc. Honest note in-lesson: the swing still rotates live (L30 hook).
- **L30 · Swing Feel** — ✅ shipped. Frame-stepped swing (the swing itself was converted
  to 4 baked frames + `tween_method` index-stepping FIRST, then the lesson written against
  final code — retired L29's `swing_to` mirror line, slash arc snapped to 15°), lunge,
  hit-stop (`ignore_time_scale` timer), camera shake via offset.
- **L31 · A Death Worth Respawning From** — ✅ shipped. dying latch, feedback-first
  take_damage, die() ceremony, show_death_screen, low-HP pulse — now marked as historical
  polling debt paid by Forge F3/L35.
- **L32 · The HUD Teaches the Game** — ✅ shipped, **arc complete (27–32)**. Hint chips
  as a reactive tutorial (evidence probes, dict-as-checklist, dim-don't-delete); the lesson
  now names Forge F3/L35 as the payoff for the durable HUD polling debt. Absorbs part of
  O5's HUD-anatomy goal.

**Numbering decision (resolved):** Game Feel lessons append in *build order* at L27–L32;
The Forge follows at L33–L36; XP and the 0002 progression arc slide after those retrofit
arcs. This preserves the course as the codebase's actual build order.

### Arc "The Overhaul, Understood" — retrofit tour *(interleavable breathers, L26-style)*
Guided tours of existing code with one hands-on tweak each (the L26 precedent: teach
what entered the repo ahead of its lesson):

- **O1 · Reading the new world** — Ground/Road/World, `z_index` vs Y-sort, why the hero
  walks behind trees. Tweak: re-anchor a prop and watch sorting break/heal.
- **O2 · The dual-grid road** — corner bits, why radius-16 circles join seamlessly.
  Tweak: hand-compute the tile for bits=6, then verify in `terrain.png`.
- **O3 · Juice — particles & tweens** — slash arc, sparks, shake, dust anatomy.
  Tweak: tune one particle system; feel the difference.
- **O4 · The pixel pipeline** — `gen_*.py`, master palette, deterministic seeds,
  the creatures→polish order dependency. Tweak: change one grass hex, rebake, run.
- **O5 · HUD anatomy** — NinePatchRect, TextureProgressBar, pixel fonts, integer
  scaling. *(Foldable into F3.)*

### Exhibit maintenance (Claude's chores — not lessons; Law 2 "fix what's broken")
1. Repair drifted lessons per the table — **after** the F3 decision (repair once).
2. Build the claims manifest + `check_lessons.py` (candidate 5); seed claims for all 26
   lessons while doing repair #1 — the inventory *is* the claims list.
3. Decide retirement story for superseded assets (`tileset.png`, `sword.png`,
   `character.png` originals) once lessons stop referencing them.

## Ultragoal review progress (2026-06-15)

- **G009 · Godot code architecture and GDScript refactor pass** — ✅ shipped. Core scripts now use explicit return/parameter/export/onready types across `player.gd`, `wolf.gd`, `hud.gd`, `sword.gd`, `combat_fx.gd`, `damage_number.gd`, `sfx.gd`, and the last untyped `CombatTable` default. Player one-shot actions moved out of `_physics_process` into `_unhandled_input`; continuous movement still polls via `Input.get_vector`. `hud.gd` remains signal-driven/no `_process`; signal connections now use `StringName` constants and base-node contracts instead of depending on ignored global-script cache refreshes. Removed the stale .NET project block from `project.godot`. Lesson 37 and `lessons/claims.json` were updated to teach/check the final event-driven input shape. Verified lesson contract (0 errors / 4 planned doc warnings), combat-table test, CombatFX test, and 120-frame boot with no script errors/warnings.
- **G010 · World, forest, and asset pipeline refactor pass** — ✅ shipped. `forest_generator.gd` now exposes scene wiring as typed NodePaths, keeps procedural state/local variables typed, and adds bounds through an explicit parent reference instead of an inline parent-chain call. Added `tests/test_forest_generator.gd`, which registers the test-only autoloads, instantiates `main.tscn`, and locks seed-1337 invariants: 3072 ground cells, 219 road cells, 431 world children, 9 wolves, camp/sword coordinates, and World Y-sort. Asset generator scripts now anchor paths to their own folder (removing the absolute `gen_props.py` output path and caller-CWD assumptions), and `assets/SPRITE_WORKFLOW.md` documents the v2 generator order plus legacy lesson-ramp assets. ForestPlan remains parked: one consumer, no generation-logic bug, and the new invariant test gives enough regression coverage without splitting plan/application yet.

## Remaining decisions / debts

1. **Input Map teaching debt:** ✅ paid by L37, "The Input Map Becomes Yours" — final
   `move_*`, `target_next`, and `attack` bindings are now taught explicitly.
2. **Repair style:** resolved in practice as hybrid repair — factual drift fixed in place,
   deliberate build-order ramps preserved with evolution notes.
3. **Retrofit depth:** keep O-lessons as guided tours unless a system's trigger demands a
   rebuild-from-scratch lesson.
4. **ForestPlan** stays parked unless its trigger fires first. G010 rechecked the trigger and kept it parked.
