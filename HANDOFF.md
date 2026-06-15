# Handoff — resume point

*Updated 2026-06-15 during Ultragoal review. Keep overwriting when stale.*

## TL;DR
The Forge engineering arc and Input Map bridge are now **complete**: F1–F4 are implemented/taught, and Lesson 37 closes the `move_*`/`target_next`/`attack` teaching debt. The active durable plan is the Ultragoal in `.omx/ultragoal/goals.json`; resume with the next pending story, **G009 — Godot code architecture and GDScript refactor pass**.

- **Branch:** `ultragoal-review-refactor` (local; not pushed or merged).
- **Durable plan:** `.omx/ultragoal/goals.json` + `.omx/ultragoal/ledger.jsonl`.
- **Record:** `learning-records/0003-architecture-review-and-curriculum-expansion.md` marks Forge F1–F4 shipped.
- **Lesson contract:** `lessons/claims.json` + `tools/check_lessons.py` now track 37 lessons.

## Done in The Forge

- **F1 / L33** — `combat_table.gd` (`class_name CombatTable`): attack-table formulas + rage as pure static funcs, cited to `reference/wow-combat-values.md`; `player.gd` rewired.
- **F2 / L34** — `tests/test_combat_table.gd`: 18 headless assertions against the combat reference.
- **F3 / L35** — HUD stops polling: player/wolf signals, HUD listeners, low-health pulse via tween; player no longer knows HUD exists.
- **F4 / L36** — `combat_fx.gd` autoload: one home for floating text, damage numbers, sparks, and blood. `player.gd`, `wolf.gd`, and `sword.gd` now ask `CombatFX`; duplicated local spawners deleted. `tests/test_combat_fx.gd` proves the factories.

- **L37 / Control Bridge** — `move_*`, `target_next`, and `attack` Input Map workflow taught explicitly; L03/L15/L19 point forward to the final map.

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

Expected current lesson checker state: **0 errors / 5 warnings**. The remaining warnings are the planned C# / mono / dotnet documentation/project audit items.

## Next up

1. **G009 — Godot code architecture and GDScript refactor pass.** Review player/wolf/HUD/sword/combat scripts for style, signal direction, shallow coupling, polling, typing, safe tweens/awaits, and stale warnings.
2. **G010–G011** — world/assets and curriculum/records cleanup. This includes the remaining C# / mono / dotnet audit warnings and any stale handoff/index wording.
3. **G012** — XP/progression readiness review, then final quality gate.

## Working model

Refactor code → back-engineer the lesson → keep code, index, claims, and learning records synchronized. Preserve deliberate build-order ramps with evolution notes; fix factual drift in place. Verify every slice before checkpointing the Ultragoal.

## Not our concern

A separate "gizmo" workflow may exist under `/home/ark/gizmo`; leave it alone.
