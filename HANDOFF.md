# Handoff — resume point

*Updated 2026-06-15 during Ultragoal review. Keep overwriting when stale.*

## TL;DR
The Forge engineering arc is now **complete**: F1–F4 are implemented, verified, taught, and committed on the local review branch. The active durable plan is the Ultragoal in `.omx/ultragoal/goals.json`; resume with the next pending story, **G008 — close the `move_*` Input Map teaching debt**, before moving into deeper architecture cleanup and XP/progression readiness.

- **Branch:** `ultragoal-review-refactor` (local; not pushed or merged).
- **Durable plan:** `.omx/ultragoal/goals.json` + `.omx/ultragoal/ledger.jsonl`.
- **Record:** `learning-records/0003-architecture-review-and-curriculum-expansion.md` marks Forge F1–F4 shipped.
- **Lesson contract:** `lessons/claims.json` + `tools/check_lessons.py` now track 36 lessons.

## Done in The Forge

- **F1 / L33** — `combat_table.gd` (`class_name CombatTable`): attack-table formulas + rage as pure static funcs, cited to `reference/wow-combat-values.md`; `player.gd` rewired.
- **F2 / L34** — `tests/test_combat_table.gd`: 18 headless assertions against the combat reference.
- **F3 / L35** — HUD stops polling: player/wolf signals, HUD listeners, low-health pulse via tween; player no longer knows HUD exists.
- **F4 / L36** — `combat_fx.gd` autoload: one home for floating text, damage numbers, sparks, and blood. `player.gd`, `wolf.gd`, and `sword.gd` now ask `CombatFX`; duplicated local spawners deleted. `tests/test_combat_fx.gd` proves the factories.

## Verify the world is green

```bash
python3 -m json.tool lessons/claims.json >/tmp/claims.ok
python3 -m py_compile tools/check_lessons.py
python3 tools/check_lessons.py

godot --headless --path projects/first-steps --import
godot --headless --path projects/first-steps --script res://tests/test_combat_table.gd
godot --headless --path projects/first-steps --script res://tests/test_combat_fx.gd
godot --headless --path projects/first-steps res://main.tscn --quit-after 120
```

Expected current lesson checker state: **0 errors / 6 warnings**. The warnings are planned debts: one missing dedicated `move_*` Input Map lesson and five C# / mono / dotnet documentation/project audit items.

## Next up

1. **G008 — close the `move_*` Input Map teaching debt.** The game uses custom `move_left/right/up/down`, `target_next`, and `attack`; L03 only forward-notes the drift. Decide the cleanest teaching repair and update lessons/index/claims/records.
2. **G009–G011** — code architecture, world/assets, and curriculum/records cleanup. This includes the remaining C# / mono / dotnet audit warnings and any stale handoff/index wording.
3. **G012** — XP/progression readiness review, then final quality gate.

## Working model

Refactor code → back-engineer the lesson → keep code, index, claims, and learning records synchronized. Preserve deliberate build-order ramps with evolution notes; fix factual drift in place. Verify every slice before checkpointing the Ultragoal.

## Not our concern

A separate "gizmo" workflow may exist under `/home/ark/gizmo`; leave it alone.
