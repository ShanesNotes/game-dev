# Handoff — resume point

*Updated 2026-06-15 during Ultragoal review. Keep overwriting when stale.*

## TL;DR
The Forge engineering arc, Input Map bridge, first Godot architecture pass, world/assets pass, curriculum/records cleanup, and progression readiness review are now **complete**: F1–F4 are implemented/taught, Lesson 37 closes the `move_*`/`target_next`/`attack` teaching debt, G009 typed/cleaned the core combat/HUD scripts, G010 hardened the forest generator plus asset pipeline, G011 synced durable docs, and G012 added a tested XP formula seam without wiring gameplay. The active durable plan is the Ultragoal in `.omx/ultragoal/goals.json`; resume with the final pending story, **G013 — final verification, cleanup, and review gate**.

- **Branch:** `ultragoal-review-refactor` (local; not pushed or merged).
- **Durable plan:** `.omx/ultragoal/goals.json` + `.omx/ultragoal/ledger.jsonl`.
- **Record:** `learning-records/0003-architecture-review-and-curriculum-expansion.md` marks Forge F1–F4, L37, and G009–G012 shipped.
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

## Done in progression readiness

- **G012 / Progression math** — `progression_table.gd` is a pure, tested formula module for XP-to-next, mob kill XP, con colors, gray levels, and ZD thresholds. It is not wired into `player.gd`; Lesson 38 should still build XP state, HUD display, and ding feedback by hand.
- **G012 / Test** — `tests/test_progression_table.gd` locks low-level XP table values, same/higher/lower/gray/elite XP, and con-color thresholds.
- **G012 / Records** — `reference/wow-combat-values.md` and `learning-records/0002` now reflect the corrected +2-yellow/+3-orange con-color rule and post-L37 progression numbering.

## Done in docs/records cleanup

- **G011 / Docs** — `README.md`, `GUIDE.md`, `TELOS.md`, `NOTES.md`, `MISSION.md`, `RESOURCES.md`, and this handoff now describe the current GDScript-only, 37-lesson state instead of the older 26-lesson / runtime-flavor wording.
- **G011 / Records** — `learning-records/0003-architecture-review-and-curriculum-expansion.md` now includes the G011 checkpoint and current remaining debts. Historical `0001` wording was normalized to GDScript-only.
- **G011 / Contract** — `lessons/claims.json` no longer allow-lists the stale scanned doc strings; future non-GDScript runtime drift should show up as a checker warning.

## Verify the world is green

```bash
python3 -m json.tool lessons/claims.json >/tmp/claims.ok
python3 -m py_compile tools/check_lessons.py
python3 tools/check_lessons.py

godot --headless --path projects/first-steps --import
godot --headless --path projects/first-steps --script res://tests/test_combat_table.gd
godot --headless --path projects/first-steps --script res://tests/test_combat_fx.gd
godot --headless --audio-driver Dummy --path projects/first-steps --script res://tests/test_forest_generator.gd
godot --headless --audio-driver Dummy --path projects/first-steps --script res://tests/test_progression_table.gd
tools/check_godot_boot.sh 3
```

Expected current lesson checker state: **0 errors / 0 warnings**. The stale project/runtime wording is gone from scanned docs.

## Next up

1. **G013** — final verification, ai-slop cleanup, and independent review gate.
2. After G013, the next learner-facing build is **Lesson 38 — XP & leveling**.

## Working model

Refactor code → back-engineer the lesson → keep code, index, claims, and learning records synchronized. Preserve deliberate build-order ramps with evolution notes; fix factual drift in place. Verify every slice before checkpointing the Ultragoal.

## Not our concern

A separate "gizmo" workflow may exist under `/home/ark/gizmo`; leave it alone.
