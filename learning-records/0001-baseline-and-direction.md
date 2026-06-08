# 0001 — Baseline & Direction

**Date:** 2026-06-07 · **last updated:** 2026-06-08

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
- **Reusable scenes** are now in the toolkit (L16) — the move for the pack.

## What's next
- **A wolf pack** — turn the Wolf into a reusable `.tscn` and instance several.
  Upgrade the player's melee from the hardcoded `get_node_or_null("../Wolf")` to
  hit-all-in-range via an Area2D hitbox + groups, so it scales to many enemies.
- Then the final story leg: **travel north to a cabin** (a scene transition).

## Deferred / backlog (only if asked)
- Player `in_combat` flag to gate resting/regen — the learner wants the player put
  into combat too; meaningful once regen exists.
- Teased but not taken: idle facing-frame poses; coloured (green→red) health bar +
  hurt flash; crit damage numbers (bigger/yellow) + sideways drift; wolf sprints
  home / untargetable while evading; de-aggro timer + heal-on-reset; sound;
  character visibly holding the sword; XP/loot on kill.
- **Offered, not yet taken:** a reference card on transforms + collision layers.
