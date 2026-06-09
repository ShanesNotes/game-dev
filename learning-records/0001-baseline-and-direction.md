# 0001 — Baseline & Direction

**Date:** 2026-06-07 · **last updated:** 2026-06-08 (L18)

## Starting point
- Total beginner to game development. No prior Godot or engine experience.
- **Has NEVER written code in any language.** Only osmosis from driving CLI coding
  tools over the past ~year. Treat all programming concepts (variables, functions,
  loops, types) as brand new — teach the programming, not just the Godot syntax.
- Some experience driving AI coding tools (Codex, Claude Code, Grok) — but "have the
  AI build the whole game" attempts failed. Wants to learn the craft, not delegate it.

## Direction
- GDScript (not C#).
- 2D, top-down adventure/sim vibe as a loose compass (Zelda / Stardew / Pokémon).
- Hobby pace, exploratory — discovering preferences is itself a goal.
- Throughline: a tiny playable story, one mechanic per lesson, modelled on WoW's
  Elwynn Forest — find a sword → a wolf appears → a real combat encounter →
  (later) travel north to a cabin. Every mechanic earns its place in a story.

## How to teach this learner
- Tiny, single-win lessons: one concept + an immediate tangible result each time.
- Build the nodes/scenes mental model before scripting; name each new code idea.
- Don't over-explain; let curiosity pull the depth (the learner asks the teacher).
- Conceptual and engaged — happy to reference WoW mechanics and reason about design
  trade-offs. Will spot rough edges and ask to refine them.

## Lessons delivered (all DONE)

### Foundations
1. **Nodes, scenes, first sprite** — the node tree; no code yet.
2. **First GDScript** — `_process`/`delta`, variables, auto-move.
3. **Player input** — `if`, `Input.is_action_pressed`, `Vector2`, 2D y-down.
4. **Collision** — CharacterBody2D / CollisionShape2D / StaticBody2D, `velocity`,
   `move_and_slide()`, `_physics_process`. First scene restructuring.
5. **Tile floor** — TileSet / TileMapLayer, atlas slicing, draw order (editor-only).
6. **Camera follow** — Camera2D as a child of Player; parent-child transforms.
7. ★ **Animated character** — AnimatedSprite2D, SpriteFrames, facing by direction.
   New code: `$Name`, `@onready`, first hand-written function w/ parameter,
   `else`, `return`, `abs()`.

### The encounter
8. **Find the sword** — Area2D + SIGNALS (event-driven), `body_entered`, editor
   signal connection, `print()`, `queue_free()`, `==`.
9. **The wolf** — chase AI: `get_node("../Path")`, `global_position`, vector
   subtraction for direction, `normalized()` (the tool teased in L3), `flip_h`.
10. **Aggro & leash STATE MACHINE** — `@export`, `enum`, `match`, `distance_to()`,
    `_ready()`, IDLE/CHASE/RETURN. The "be in one state, switch on events" pattern.

### Combat
11. **Combat: aggro aura + swing timer** — an Area2D aura
    (`body_entered`/`body_exited`) turns combat on/off; a Timer node drives the
    swing. The wolf brain collapses to `var target` (player|null). Teaches
    events-over-polling.
12. **Return to spawn** — `_ready` records `spawn`; walk home when `target == null`.
13. **Health + health bar** — player `max_health`/`health`, CanvasLayer + ProgressBar
    HUD, `take_damage()`, death = `reload_current_scene()`; the wolf's bite calls
    `target.take_damage(swing_damage)` (nodes calling each other's methods).
14. **Fight back** — custom `attack` Input action, `is_action_just_pressed`, GCD via
    one-shot Timer + `can_attack`, distance-check melee, wolf health + floating bar +
    death via `queue_free`. Combat loop complete: pull → trade blows → win or die.

### Polish
15. **Player auto-attack** — a repeating swing timer that mirrors the wolf; engages on
    attack press or on taking damage. `is_instance_valid`, default param `from=null`.
    Combat is now symmetric. Left an `# Abilities go here` hook for later.
16. **Damage numbers + REUSABLE SCENES** — `damage_number.tscn` (Label + Tween
    float-up/fade + `tween_callback(queue_free)`), `preload`/`instantiate`/`add_child`.
    The instancing pattern behind bullets/coins/enemies — direct prereq for the pack.
17. **Controller support** — `Input.get_vector` (analog + deadzone + length-clamp,
    which also finally fixes the L3 diagonal-speed bug); gamepad button added to the
    `attack` action.

### The pack
18. **Wolf pack — CLICK TARGETING** — `Save Branch as Scene` turns the built Wolf into a
    reusable `wolf.tscn`; drag 3 copies into Main (each gets its own aura/timer/brain for
    free). Player single-target (`"../Wolf"`) breaks → replaced by WoW-style click
    targeting: wolf `input_pickable` + `input_event` → `get_first_node_in_group("player")
    .set_target(self)`; player keeps `var target`/`attack_range`, `swing()` hits the
    current target, clicking another wolf redirects (no swing-timer reset = WoW-accurate).
    Gold-tint highlight via `set_targeted()`. **NOTE:** auto-attack stays single-target;
    the AoE (Area2D hitbox + "enemies" group) is deferred to a **Whirlwind** ability later.
19. **Wielding the sword** — held `Sword` Sprite2D child on the Player + a Tween slash arc
    (`rotation_degrees` out/back) fired from `swing()`; the L8 pickup now calls
    `equip_sword()` to reveal it. Offset-pivot so it rotates at the hilt. Weapon visibility
    is a deliberate stepping stone → data-driven `WeaponData` equip system at L27 (YAGNI).

### Combat depth (numbers from `reference/wow-combat-values.md`)
20. **Swing timing & levels** — white swing timer = `@export weapon_speed` (~2.0s, fed to
    the Timer in `_ready`); GCD explained (1.5s, abilities only — deliberately not wired,
    no dead code); `@export var level` on player + wolves with a per-wolf `LevelLabel`
    (Wolf/Wolf2/Wolf3 = L1/L2/L3 via per-instance export). Foundation for the hit table.
21. **Attack table I — hit or miss** — the one-roll model: `randf()*100` read against banded
    outcomes. First band = Miss (`5% + Δ×0.1`, Δ = level-gap × 5); the rest = Hit. Routed
    `swing()` → `attack(t)`; "Miss" floating text via a `damage_number.show_text` refactor
    (numbers now route through it). Only the *player's* attacks roll the table so far.
22. **Attack table II — crits** — carve a Crit band after Miss: `crit_chance = base_crit −
    1%/level above`, floored at 0; **200% (double)** damage; big yellow numbers via a `size`
    param on `show_text` + an `is_crit` flag (default false) on the wolf's `take_damage`.
23. **Attack table III — dodge & parry** — two avoidance bands between Miss and Crit:
    `dodge = 5% + 0.5%/level above`, `parry = 5% + 3%/level above` (matches WoW's ~8/11/14%
    at +1/+2/+3); checked against running totals, before crit. Front-only parry noted but
    not facing-gated (the wolf always faces you). Cyan "Dodge" / orange "Parry" text.

## Key decisions & teaching threads
- **Events over polling.** The wolf moved from a polling state machine (L10) to an
  event-driven aura (L11). Recurring theme: prefer signals to per-frame checks, and
  reach for the simplest thing that works.
- **Combat is symmetric.** Player and wolf both run swing timers and call each
  other's `take_damage`. A clean mental model for scaling to more enemies.
- **Collision stays simple.** Everything is on collision **layer 1** — wolf and
  player are solid and collide; the aura and sword still detect via the default
  mask 1. The learner explicitly wants wolf + player solid. **Do NOT re-suggest
  separating collision layers.**
- **Reusable scenes** are now in the toolkit (L16) — the move applied to the wolf in L18.
- **Click-to-target, single-target auto-attack** (L18): wolves are clickable
  (`input_pickable` + `input_event`), the player is found via a `"player"` group, and the
  white swing follows the current `target`. The recurring "stop pointing at one named node"
  lesson. The *enemies*-group + Area2D AoE is deferred to the Whirlwind ability (L33).
- **The attack table is built incrementally** (L21+): one `randf()*100` roll, outcomes as
  ordered bands (Miss → … → Crit → Hit). Each combat lesson slots a new band into the
  *same* roll. Numbers come from `reference/wow-combat-values.md`; only the player's swings
  roll it so far (the wolves' side comes with dodge/parry/block).

## What's next
- **See [`0002-roadmap-combat-quests-progression.md`](0002-roadmap-combat-quests-progression.md)** —
  a 15-lesson arc (full Classic combat table, rage, XP/leveling, real inventory, wizard
  quests, Heroic Strike, Whirlwind), grounded in [`reference/wow-combat-values.md`](../reference/wow-combat-values.md).
  Player is now a **Warrior** (sword + rage). Do one at a time.
- **Then travel north to the cabin** — the final story leg: the player's first **scene
  transition** (`change_scene_to_file` / packed scene), a second map, a door/edge trigger.
- Teased in L18, take if asked: **spawn the pack from code** (the "spawner" pattern —
  `preload` + `instantiate` loop, waves/dungeons); **swing arc** (hit only wolves in
  front, not a full ring).

## Game-feel / juice backlog (offered, take anytime)
- **Crit punch** (teased L22): tiny **screen shake** and/or a **scale-pop** on the crit
  number; **crit numbers drift sideways** so they don't overlap.
- **Agility stat** that raises `base_crit` (and later feeds the stat/leveling system).
- **Hit-stop**: a few-frame freeze on big/killing hits.
- **Hurt flash** (white/red blink) on taking damage; **coloured (green→red) health bars**.
- **Sound**: attack whoosh, impact, crit sting.
- **Facing-aware sword**: held sword switches side/angle with movement direction.

## Deferred / backlog (only if asked)
- Player `in_combat` flag to gate resting/regen — the learner wants the player put
  into combat too; meaningful once regen exists.
- Teased but not taken: idle facing-frame poses; wolf sprints home / untargetable while
  evading; de-aggro timer + heal-on-reset; XP/loot on kill (now formalised in roadmap 0002).
- **Offered, not yet taken:** a reference card on transforms + collision layers.
