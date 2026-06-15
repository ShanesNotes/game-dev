# Handoff — resume point

*Updated 2026-06-15 during Ultragoal review. Keep overwriting when stale.*

## TL;DR
The Forge engineering arc, Input Map bridge, first Godot architecture pass, and world/assets pass are now **complete**: F1–F4 are implemented/taught, Lesson 37 closes the `move_*`/`target_next`/`attack` teaching debt, G009 typed/cleaned the core combat/HUD scripts, and G010 hardened the forest generator plus asset pipeline. The active durable plan is the Ultragoal in `.omx/ultragoal/goals.json`; resume with the next pending story, **G011 — curriculum architecture and durable records cleanup**.

- **Branch:** `ultragoal-review-refactor` (local; not pushed or merged).
- **Durable plan:** `.omx/ultragoal/goals.json` + `.omx/ultragoal/ledger.jsonl`.
- **Record:** `learning-records/0003-architecture-review-and-curriculum-expansion.md` marks Forge F1–F4, L37, G009, and G010 shipped.
- **Lesson contract:** `lessons/claims.json` + `tools/check_lessons.py` now track 37 lessons.

## Done in The Forge

- **F1 / L33** — `combat_table.gd` (`class_name CombatTable`): attack-table formulas + rage as pure static funcs, cited to `reference/wow-combat-values.md`; `player.gd` rewired.
- **F2 / L34** — `tests/test_combat_table.gd`: 18 headless assertions against the combat reference.
- **F3 / L35** — HUD stops polling: player/wolf signals, HUD listeners, low-health pulse via tween; player no longer knows HUD exists.
- **F4 / L36** — `combat_fx.gd` autoload: one home for floating text, damage numbers, sparks, and blood. `player.gd`, `wolf.gd`, and `sword.gd` now ask `CombatFX`; duplicated local spawners deleted. `tests/test_combat_fx.gd` proves the factories.

- **L37 / Control Bridge** — `move_*`, `target_next`, and `attack` Input Map workflow taught explicitly; L03/L15/L19 point forward to the final map. The G009 refactor now teaches the final `_unhandled_input` event shape and `StringName` action constants.

## Done in the world/assets pass

- **G010 / Forest** — `forest_generator.gd` now uses exported NodePath wiring for Road/World/Player/Sword/bounds, explicit typed procedural state, and no remaining parent-chain add. Added `tests/test_forest_generator.gd` to lock seed-1337 world invariants (ground cells, road cells, child count, wolves, player/sword positions, Y-sort).
- **G010 / Assets** — generator scripts no longer depend on `/home/ark/...` or caller CWD. `SPRITE_WORKFLOW.md` now documents current generator order, legacy ramp assets, and v2 asset outputs. Temp-copy rebuild of all generators passed without mutating repo assets.
- **ForestPlan decision** — remains parked: still one consumer, no generation-logic bug found, and the new invariant test gives regression coverage without splitting pure plan/apply layers yet.

## Verify the world is green

```bash
python3 -m json.tool lessons/claims.json >/tmp/claims.ok
python3 -m py_compile tools/check_lessons.py
python3 tools/check_lessons.py

godot --headless --path projects/first-steps --import
godot --headless --path projects/first-steps --script res://tests/test_combat_table.gd
godot --headless --path projects/first-steps --script res://tests/test_combat_fx.gd
godot --headless --audio-driver Dummy --path projects/first-steps --script res://tests/test_forest_generator.gd
godot --headless --audio-driver Dummy --path projects/first-steps res://main.tscn --quit-after 120
```

Expected current lesson checker state: **0 errors / 4 warnings**. The stale .NET project section is gone; the remaining warnings are planned C# / mono wording in top-level docs for G011.

## Next up

1. **G011 — curriculum/records cleanup.** This includes the remaining C# / mono wording warnings and any stale handoff/index wording.
2. **G012** — XP/progression readiness review after the docs are clean.
3. **G013** — final verification, ai-slop cleanup, and independent review gate.

## Working model

Refactor code → back-engineer the lesson → keep code, index, claims, and learning records synchronized. Preserve deliberate build-order ramps with evolution notes; fix factual drift in place. Verify every slice before checkpointing the Ultragoal.

## Not our concern

A separate "gizmo" workflow may exist under `/home/ark/gizmo`; leave it alone.
