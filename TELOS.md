# Telos

*The why behind the why. Produced and maintained by `/goal` — run it whenever
the work starts to feel busy instead of purposeful.*

> **Changelog:** 2026-06-10 — first distillation, from MISSION.md,
> learning-records 0001–0002, NOTES.md, and 7 commits of history.
> 2026-06-10 (later) — curriculum v2: lessons re-sequenced/deepened so the course
> is the codebase's build order (serves the packaging telos; the laws unchanged).
> 2026-06-11 — housekeeping sync: 26 lessons (0026 = procedural forest per
> lessons/index.html + learning-records/0002); next aligned is 27 XP & leveling.
> Current state updated to match shipped reality (no law changes).

## Prime mover

Past attempts to have an AI "build the whole game" went nowhere. The mission
says it plainly: the goal is to **actually understand how games are built** —
well enough to discover what kind of game is worth making. The game is the
curriculum, not the product.

## Telos

**Become someone who understands the craft of game development** — one
genuinely understood mechanic at a time — with taste discovered along the way.

Test it: if the wolf project were deleted tomorrow but the understanding
remained, the mission would still be succeeding. The inverse — a finished game
the learner can't explain — is the precise failure this workspace was built to
escape.

A second, newer telos rides alongside it (public promise, X, 2026-06):
**package the process itself** so others can run the same loop. The repo is
therefore both a workspace and an exhibit.

## The laws

Principles that have actually been enforced, not just stated:

1. **One lesson, one win.** Every lesson ends with one tangible, visible
   result. Enforced 25 times; lessons that grew were split, never bloated.
2. **The learner writes the code.** Claude teaches, explains, and reviews; the
   hands on the keyboard in Godot are the learner's. (This file's maintainer
   included: fix what's broken, never build ahead.)
3. **Every mechanic earns its place in the story.** The Elwynn throughline
   (sword → wolf → combat → cabin) exists so no feature is ever abstract.
4. **Real numbers, real sources.** Combat values come from
   `reference/wow-combat-values.md`, researched once and cited per lesson —
   never re-derived from vibes.
5. **Simplest thing that works; refactors wait for their trigger.** Events over
   polling (L11), the `WeaponData` refactor parked until a second weapon exists
   (L27), AoE deferred until it became Whirlwind's job (L33). YAGNI, enforced.
6. **Locked decisions stay locked.** E.g. collision layers stay unified —
   recorded with "do NOT re-suggest." The records are memory; respect them.

## Anti-telos

Things that would look like progress and betray the purpose:

- An AI dumping a finished system into the project "to save time."
- Skipping ahead of the roadmap because a later lesson is more exciting.
- Polishing the exhibit (guides, aesthetics, tooling) *instead of* learning —
  packaging is in service of the mission, never a substitute for it.
- Scope-creeping toward "shipping a game." Explicitly out of scope.

## Public promises

- **The packaged guide** (promised on X): the process, delivered as something
  others can replicate. Fulfilled by `GUIDE.md` + the browsable
  `lessons/index.html`; kept honest by this file.

## Current state (at distillation)

26 lessons done (Foundations through VI · The World / procedural Elwynn forest).
Playable WoW-style combat (attack table through rage) + generated forest, per
lessons/index.html, 0026-procedural-forest.html, and learning-records/0002
(reseq note). Next aligned step per roadmap 0002 + index: **Lesson 27 — XP &
leveling.** The smallest move that advances the telos is always the next single
lesson, done by hand.
