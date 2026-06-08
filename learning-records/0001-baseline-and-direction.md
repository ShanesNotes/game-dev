# 0001 — Baseline & Direction

**Date:** 2026-06-07

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

## Implications for teaching
- Tiny, single-win lessons. Concept + immediate tangible result each time.
- Build the nodes/scenes mental model before any scripting.
- Don't over-explain; let curiosity pull the depth (user will ask the teacher).

## Lesson plan (rough, revisable)
1. ✅ Nodes, scenes, first sprite on screen *(0001-nodes-scenes-first-sprite.html)* — DONE
2. ✅ First GDScript — auto-move via `_process`/`delta` *(0002...)* — DONE
3. ✅ Player input — arrow keys, `if`, `Input`, `Vector2` *(0003...)* — DONE
   - Introduced: `if`, boolean true/false, Vector2, input actions, 2D y-down.
   - Teased: diagonal-faster bug + `normalized()` fix (only if user asks).
4. ✅ Collision — CharacterBody2D/CollisionShape2D/StaticBody2D, `velocity`,
   `move_and_slide()`, `_physics_process` *(0004-collision-walls-characterbody.html)* — issued
   - First scene-restructuring lesson (node surgery). Used Debug>Visible Collision
     Shapes so walls are visible without decorative sprites. Watch for tree mistakes.
5. ✅ Tile floor — TileSet/TileMapLayer, atlas slicing, paint *(0005-tilemap-floor.html)* — issued
   - No new code (editor-only lesson, variety). Godot 4.6 uses TileMapLayer (not
     deprecated TileMap). 32px tiles.
   - ASSET: generated `projects/first-steps/assets/tileset.png` (64x32, grass|dirt)
     via PIL. Offered to generate more tiles (water/flowers/trees) on request.
   - Draw order taught: later sibling = drawn on top; floor placed first.
6. ✅ Camera follow — Camera2D as child of Player, parent-child transforms,
   position smoothing *(0006-camera-follow.html)* — issued
   - Formally named parent-child transform (used implicitly since L4).
   - Teased camera limits (clamp to map edges) on request.
7. ✅ MILESTONE: animated character — AnimatedSprite2D, SpriteFrames, facing by
   direction *(0007-animated-character-facing.html)* — issued
   - ASSET: generated `assets/character.png` (128x128, 4 frames x 4 rows:
     down/left/right/up) via PIL.
   - NEW CODE CONCEPTS (big): node refs `$Name`, `@onready`, first hand-written
     function w/ parameter (`update_animation`), `else`, `return`, `abs()`.
   - Teased: idle facing-frame poses (freeze on direction) as a tweak.

## QUEST ARC chosen by user (2026-06-07): sword → wolf → north to cabin
8. ✅ Find the sword — Area2D, SIGNALS (event-driven), `body_entered`,
   editor signal connection, `print()`, `queue_free()`, `==` *(0008-pickup-sword-signals.html)* — issued
   - ASSET: generated `assets/sword.png` (32x32) via PIL.
   - Signals = the big conceptual unlock this lesson. Taught editor-based connect.
9. ✅ The wolf — chase AI: `get_node("../Path")`, global_position, vector
   subtraction for direction, `normalized()` (cashed in the L3 diagonal tease),
   `flip_h` *(0009-wolf-chase-ai.html)* — issued
   - ASSET: generated `assets/wolf.png` (32x32 side view, faces right) via PIL.
   - Wolf speed 120 < player 200 = intentional design (escapable). Teased
     detection radius + catch-on-contact as follow-ups.
    -- USER INSIGHT: noticed naive chaser "mirrors" at distance (speed gap). Asked
       for WoW-style aggro + leash. Inserted lesson 10 (aggro/leash) before cabin.
10. ✅ Aggro & leash STATE MACHINE — `@export` (Inspector tuning), `enum`, `match`,
    `distance_to()`, `_ready()`, IDLE/CHASE/RETURN *(0010-aggro-leash-state-machine.html)* — issued
    - Most CS-heavy lesson yet; user is conceptual & engaged (referenced WoW combat).
    - Reused wolf.png. Teased: de-aggro timer, heal-on-reset, chase-break distance,
      debug-draw aggro circle.
    -- DIAGNOSIS SESSION: user reported wolf "mirrors my movements & maintains
       distance." Layer fix (player L2/wolf L4) was correct — NOT collision.
       Reproduced headless (temp Diag autoload driving real Player; logged pos),
       rendered PIL trace. ROOT CAUSE = pure pursuit + speed deficit → ORBIT-LOCK
       when player strafes/circles (distance flatlines ~118px). Not a bug; it's
       naive "aim at current position" pursuit. Cleaned up all diag artifacts.
    -- USER VISION (big reframe): wants WoW Elwynn-Forest combat, NOT a chase toy:
       aggro radius → combat state → melee range → SWING TIMER auto-attack → threat
       → health → fight back w/ sword → flee/leash if losing → PACK of wolves.
       Picked "predictive" but real want = the combat loop. Stopping at melee +
       swing timer dissolves the orbit-lock.

## COMBAT SUB-ARC roadmap
11. ✅ Swing timer — Timer node + timeout, COMBAT state, stop at melee, print bite
    *(0011-swing-timer-combat-state.html)* — DONE.
    -- BUT user found it still felt weird. RE-DIAGNOSED w/ visual tool: orbit at
       130px stays in CHASE 599/600 frames, COMBAT never triggers (melee only 40px),
       orbit-lock persists. User insight: 4-state machine overcomplicated; wants an
       "aura" that triggers combat on enter. CORRECT — refactored.
12. ✅ REFACTOR: Combat Aura — replaced 4-state polling machine with Area2D aura +
    body_entered/body_exited signals; brain collapses to `var target` (player|null).
    ~40 lines → ~25. Event-driven > polling. *(0012-combat-aura-refactor.html)* — issued
    -- KEY TEACHING THREAD: prefer events over per-frame polling; simplicity first.
    -- Honest note given: trailing-follow during active combat is WoW-accurate; the
       real problem was the unreliable trigger, which the aura fixes.
    -- DEFERRED: formal PLAYER combat-mode flag → do in L13 (health), where it gates
       resting/regen. User explicitly wants the player put into combat too.
    -- BUG SESSION (post-refactor): user reported wolf "maintains perfect distance,
       repelled, won't engage." Inspected scene: (1) collision layers had REVERTED to
       default (all layer 1); (2) REAL CAUSE = wolf's child nodes (Sprite/Collision/
       AggroArea) all offset ~(339,-189) from the Wolf node origin → code steers the
       node origin (invisible, ~388px from the visible wolf) so the sprite parks 388px
       away. Fix: zero child positions, move the Wolf NODE. Lesson learned = "move the
       body not the parts; code reads the parent's position."
    -- USER DECISION: KEEP collision — wants wolf+player SOLID. So we do NOT separate
       layers; everything stays on layer 1 (they collide; aura/sword still detect via
       mask 1). Do not re-suggest layer separation.
13. ✅ Return to spawn — re-add `_ready` + `spawn`, walk home when target==null
    *(0013-return-to-spawn.html)* — issued. Small lesson, completes aura behavior.
14. ✅ Health + health bar — player max_health/health, CanvasLayer+ProgressBar HUD
    (`HealthBar`), `take_damage()`, death=`reload_current_scene()`; wolf bite now
    calls `target.take_damage(swing_damage)` *(0014-health-and-health-bars.html)* — issued
    - NEW: CanvasLayer, ProgressBar, nodes calling each other's METHODS (direct call
      vs signals), clamp health>=0, reload_current_scene.
    - PLAYER-only bar this lesson (wolf HP deferred to L15 where sword can hurt it).
    - Told user to bump wolf Swing Damage ~3 in Inspector (was 1).
    - Deferred again: player in_combat flag (needs regen to matter).
    - Teased: coloured/green→red bar, floating bar over wolf, hurt flash.
15. ✅ Fight back — Input Map custom action `attack` (Space), `is_action_just_pressed`
    vs `is_action_pressed`, GCD via one-shot Timer + `can_attack` flag, distance-check
    melee dmg (`get_node_or_null("../Wolf")` + `wolf.take_damage`), WOLF health +
    floating ProgressBar + death via `queue_free` *(0015-fight-back-sword.html)* — issued
    - COMBAT LOOP COMPLETE: pull → trade blows → win or die. Big milestone.
    - NEW: Input Map, just_pressed, cooldown pattern (GCD), reciprocal take_damage.
    - Tuning: player atk_dmg 4 / range 60 / GCD 0.6s; wolf hp 12, swing 3. Winnable.
    - Melee = simple distance check (single wolf). UPGRADE to Area2D hitbox + groups
      when we do the pack (so it scales to many enemies).
    - Teased: swing anim/flash, require facing, require owning sword, XP/loot drop.
## POLISH ARC (user request after first kill)
16. Player AUTO-ATTACK swing timer (WoW): attack key starts auto-attack on a repeating
    swing timer (mirror wolf); also starts when damage taken from enemy. Ability hook
    left for button press (not coded). target acquisition + is_instance_valid, default
    param `from=null`, wolf passes self on bite. (this lesson)
17. ✅ DAMAGE NUMBERS + REUSABLE SCENES — built damage_number.tscn (Label root +
    damage_number.gd: setup(amount,color), Tween float-up+fade, tween_callback
    queue_free). preload/instantiate/add_child. Red over player, white over wolf,
    spawned in each take_damage *(0017-damage-numbers-reusable-scenes.html)* — issued
    - KEY SKILL: reusable scene + instancing (the pattern behind bullets/coins/enemies;
      direct prereq for the pack). Also first Tween use.
    - spawn_number helper duplicated in player + wolf (acceptable; could refactor to
      autoload later). Numbers parented to Main so they float in place.
    - Teased: crit numbers (bigger/yellow), sideways drift.
18. ✅ CONTROLLER support — switched player movement to `Input.get_vector` (analog +
    deadzone + length-clamp = ALSO finally fixes the L3 diagonal-speed bug); added
    joypad button to `attack` action in Input Map *(0018-controller-support.html)* — issued
    - ui_* actions already bound to stick/dpad by default → movement "just works".
    - Action-based input = adding a gamepad event needs zero code change.
    - Teased: deadzone tuning, rumble on hit, dynamic UI prompts.
POLISH ARC COMPLETE (auto-attack, damage numbers, controller).
19. (next) A PACK — turn Wolf into reusable .tscn, instance several; upgrade melee to
    hit-all-in-range via groups (player attack currently hardcodes "../Wolf"). Then:
    north to the cabin.
16. Threat + flee/leash reset, regen-on-reset.
17. A pack — make Wolf a reusable .tscn scene, instance several.
LATER: travel north to the cabin (scene transition).
OFFERED (not yet taken): reference card on transforms + collision layers.

Foundation complete as of L7 (move/collide/tiles/camera/animation).
Backlog tweaks if asked: idle facing poses, normalized() diagonal fix, HUD/UI, sound,
character visibly holding the sword.
4. Scenes as reusable units (instance a second thing)
5. Collision / interaction basics
