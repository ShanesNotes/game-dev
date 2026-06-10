---
description: Gather the telos of this workspace, audit current work against it, and update TELOS.md
---

# /goal — the telos audit

You are auditing this workspace's *telos*: not what is being built, but what the
building is **for**. Run the full protocol below. If arguments were given, they
describe proposed work to judge against the telos: $ARGUMENTS

## 1 · Gather (evidence before opinion)

Read, in this order — later sources override earlier ones where they conflict:

1. `MISSION.md` — the stated why, success criteria, constraints, out-of-scope.
2. `learning-records/` (all, newest last) — what actually happened, decisions
   locked, threads in flight. This is ground truth for *how the learner learns*.
3. `NOTES.md` — teaching preferences and environment facts.
4. The newest roadmap record — the promised arc and its sequencing logic.
5. `git log --oneline -20` — what the work itself says the priorities are.
6. `TELOS.md` — the previous distillation (you are about to test it).

## 2 · Distill (the why behind the why)

Answer each, in one or two sentences, citing the evidence:

- **Prime mover** — what failure or desire started this? (Look for it in the
  mission's own words.)
- **Telos** — the end state pursued for its own sake. Test: if it were achieved
  but every artifact deleted, would the person still be satisfied?
- **The laws** — the 3–6 operating principles that recur across records and
  decisions. A law must have been *enforced* at least once (a refactor refused,
  a feature deferred) to count.
- **Anti-telos** — what would *look* like progress but betray the purpose?
  Name the specific temptations of this workspace.
- **Public promises** — anything committed to an outside audience.

## 3 · Audit (drift check)

- Score the last ~5 commits and any in-flight work against each law:
  aligned / neutral / drifting. Cite specifics.
- If `$ARGUMENTS` proposed work: give a verdict — **aligned** (do it),
  **aligned-with-changes** (state the changes), or **anti-telos** (say which
  law it breaks and what to do instead).
- Name the single *smallest* next step that most advances the telos.

## 4 · Record

- If the distillation differs from `TELOS.md`, update `TELOS.md` (keep its
  structure; note what changed and why in its changelog line).
- Report back: telos in one sentence, the verdict(s), the smallest next step.

## Guardrails

- The telos here is *learning the craft*. Never "help" by writing the learner's
  game code for them, beyond fixing what is demonstrably broken — that is the
  exact failure mode this workspace exists to escape.
- Honour locked decisions in the learning records (e.g. things marked
  "do NOT re-suggest").
- Prefer the mission's own words over your paraphrase when they are sharper.
