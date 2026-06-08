# Mission: Game Development with Godot

## Why
Learn game development as a hobby, hands-on. Past attempts to make an AI just
"build the whole game" went nowhere — the goal now is to *actually understand*
how games are built, well enough to start seeing what kind of game I want to make.

## Success looks like
- Comfortable navigating Godot and building a small 2D scene from scratch
- Can read and write GDScript well enough to make things move and respond to input
- Have built a few tiny playable things, enough to discover what genre I enjoy
- The "top-down adventure/sim" feel (Zelda / Stardew / Pokémon) as a loose direction

## Constraints
- Engine: Godot 4.6.2 stable, **GDScript** (not C#)
- Hobby pace — explore when time allows, no deadline
- Total beginner: learning by doing, one small win at a time

## Current quest arc (the throughline we're building, chosen 2026-06-07)
A tiny playable story, one mechanic per lesson:
1. **Find a sword** — an item you pick up (→ Area2D + signals)
2. **A wolf appears** — DONE (chase + aggro/leash state machine).
3. **Combat encounter** (expanded — the real goal): WoW-style. Aggro radius →
   enter combat → run to melee range → **swing-timer auto-attack** → threat →
   health → **fight back with the sword** → flee/leash if losing → a **pack** of
   wolves. Model: Elwynn Forest. GCD/swing-timer tick-based melee.
4. **Travel north to a cabin** — scene transition (after the combat arc).
This gives every new mechanic a *reason to exist* inside a story I care about.

## Out of scope (for now)
- C# / .NET — revisit only if GDScript ever becomes limiting
- 3D — staying 2D while learning fundamentals
- Shipping/publishing a finished game — exploration first
