# Handoff — resume point

*Written 2026-06-14. Delete or overwrite when stale.*

## TL;DR
We're mid-way through **The Forge** — the engineering arc that turns the combat core into
tested, decoupled modules. **F1–F3 are done, verified, and committed.** Resume at **F4**,
then the **XP & leveling** arc.

- **Branch:** `add-godot-agent-tooling` (a clean linear extension of `main` + 3 Godot-tooling
  commits). The Forge work is commit **`5cc8e0a`** on top. Not yet merged to `main`, not pushed.
- **Durable record:** `learning-records/0003-architecture-review-and-curriculum-expansion.md`
  (Forge section marked shipped). Native memory `architecture-review-backlog-0003.md` mirrors this.

## How we're working (the model — keep doing this)
Full autonomy granted to refactor + re-sequence ("not attached to the sequence"). But the repo's
telos is **the learner understanding the craft**, and "AI dumps a finished system" is the named
anti-telos. Reconciliation (proven in the Game Feel arc): **refactor the code → back-engineer
the lesson against the final code → code and curriculum stay in sync.** Nothing enters the repo
unexplained. Verify every slice (Law 4).

**Locked decision — repair style = Hybrid:** fix factual drift in place; preserve deliberate
build-order ramps as-is + add a forward-note where the real code diverged. (e.g. L2 `Sprite2D` →
L4 `CharacterBody2D` is a *ramp*, not drift; the `ui_*`→`move_*` input change got a forward-note
in L3, not a rewrite.)

## Done this session (committed in 5cc8e0a)
- **F1 / L33** — `combat_table.gd` (`class_name CombatTable`): 7 attack-table formulas + rage as
  pure static funcs, cited to `reference/wow-combat-values.md`. `player.gd` rewired; 358→326 lines.
- **F2 / L34** — `tests/test_combat_table.gd`: repo's **first test**, 18 assertions, headless.
- **F3 / L35** — HUD stops polling. `player.gd` has 8 signals + zero HUD refs; `wolf.gd` emits
  `health_changed`/`died`; `sword.gd` uses `body.announce()`; `hud.gd` `_process` deleted, all
  signal-driven, low-health pulse → looping tween. "Delete HUD, game runs" verified.
- `lessons/index.html`: new arc **VIII · The Forge** (35 lessons).

## Verify the world is still green (run on resume)
```bash
# combat test — expect: PASS — all combat-table values match wow-combat-values.md
godot --headless --path projects/first-steps --script res://tests/test_combat_table.gd
# full boot, autoloads on — expect: no SCRIPT ERROR lines
godot --headless --path projects/first-steps res://main.tscn --quit-after 120
```
Note: a Godot editor is usually open on the project; after adding any `class_name` file, the
on-disk class cache can be stale — regenerate with `godot --headless --path projects/first-steps --import`.

## Next up
1. **F4 — CombatFX home → L36** (last Forge step). De-duplicate the damage-number + particle
   spawners: `player.gd` `spawn_text_over` / `spawn_number` / `spawn_sparks` and `wolf.gd`
   `spawn_number` / `spawn_blood` collapse into one shared `CombatFX` autoload. Teaches autoloads
   (same pattern as `Sfx`). Then update index → 36 lessons + mark F4 shipped in 0003/memory.
2. **XP & leveling → L37+** — the progression arc (`learning-records/0002`), mob-XP formula from
   the reference §7, now resting on a tested, decoupled combat core.

## Open gaps / debts
- **`move_*` Input Map lesson still owed.** The game uses custom `move_left/right/up/down`
  (WASD + arrows + gamepad) but no lesson teaches creating them; L3 only has a forward-note.
  A short dedicated lesson at the overhaul point would close it.
- **Nothing pushed; not on `main`.** Decide later whether the Forge lands on `main` directly or
  via the `add-godot-agent-tooling` branch.
- **`tests/` is a new convention** — only `test_combat_table.gd` so far. A "run all tests" runner
  is a natural future addition (mentioned in L34's teacher note).

## Not our concern
A separate "gizmo" codex/omx workflow runs in `/home/ark/gizmo` (different folder). It never
touched this repo. Leave it alone (user confirmed).
