# 0003 — Architecture review & curriculum expansion (the overhaul, reconciled)

**Date:** 2026-06-11 · status: **backlog / planning** (decisions deferred to an attentive session)

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
  `attack` gains Space + A-button. *(Contradicts L03's `ui_*` teaching — see drift table.)*
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

### 3 · CombatFX — one home for floating text & bursts · **Worth exploring**
- **Files:** `player.gd:140,204,230`, `wolf.gd:70,101`.
- **Problem:** five near-duplicate spawners (`spawn_text_over`, `spawn_number` ×2,
  `spawn_sparks`, `spawn_blood`), each assuming scene-tree shape via
  `get_parent().add_child`.
- **Solution:** a `CombatFX` **autoload**: `number(at, amount, opts)` / `text(at, s, color)`
  / `burst(at, color, n)`, spawning into a dedicated FX layer.
- **Benefits:** modest deletion-test pass; teaches **autoloads** (core Godot concept
  absent from the curriculum). Could ride along with candidate 2's lesson.

### 4 · ForestPlan — split the plan from the planting · **Parked (Law 5)**
- **Files:** `forest_generator.gd` (298 lines).
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

0002's sequence stays intact (XP=27 … Whirlwind=34 → cabin). Two new arcs slot around
it; whether they renumber 27+ (the v2 precedent) or append is an **open decision**.

### Arc "The Forge" — engineering the combat core *(before/with the XP lesson)*
One win each; all triggers fired:

- **F1 · The attack table becomes a module** — extract `CombatTable`; win: *game plays
  identically with combat math in one cited file*. Teaches `class_name`, static funcs,
  value objects, the deletion test as an idea.
- **F2 · The first test** — win: *combat values verified in the terminal with the game
  closed*. Teaches `godot --headless --script`, seeded RNG, asserting against
  `wow-combat-values.md`. (The repo currently has zero tests.)
- **F3 · Events over polling II — the HUD stops spying** — win: *delete the HUD scene
  and the game still runs*. Teaches custom signals; deletes `hud.gd._process`; revisits
  L11 doctrine. *(Optionally absorbs F4.)*
- **F4 · One home for combat FX** *(optional/foldable)* — win: *five spawners become
  three functions*. Teaches autoloads.

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

## Open decisions for the attentive session

1. **Numbering:** renumber 27+ to make room for The Forge (v2 precedent), or append
   arcs after 34? (Forge wants to precede XP didactically.)
2. **Repair style** for drifted lessons: in-place rewrite vs. an "evolution note" box
   (preserves the historical build order the early lessons document).
3. **F4 (CombatFX):** own lesson, folded into F3, or parked?
4. **Retrofit depth:** are O-lessons guided tours (read + one tweak, like L26) or
   rebuild-from-scratch? (Tours respect hobby pace; rebuilds repay Law 2 more fully.)
5. **ForestPlan** stays parked unless its trigger fires first.
