# The Workspace Method

**Learning a real skill with an AI teacher — the process behind this repo,
packaged so you can run it yourself.**

This repository is a live example: a total beginner (never wrote code in any
language) learning Godot game development, 25 lessons in, with a playable
WoW-style combat system built entirely by their own hands. This guide explains
the method that got there. Substitute your own subject freely — the method
doesn't care that this one is game dev.

---

## The core inversion

Most people use AI as a **builder**: "make me a game." The artifact appears;
the understanding doesn't. When the AI stalls, the project dies, because nobody
involved understands it. That failure is what started this repo (it's recorded
in [`MISSION.md`](MISSION.md)).

The method inverts the roles. **The AI is the teacher. You are the builder.**
The AI never touches your project except to teach; your hands do every step in
the actual tool. What makes this more than "chatting with a bot" is
**structure**: a small set of files that give the teacher persistent memory,
grounding, and taste — so lesson 25 builds on lesson 3, and nothing is taught
twice or out of order.

## Anatomy of a teaching workspace

Seven artifacts. Each one answers a question the teacher would otherwise have
to guess at:

| Artifact | Question it answers | This repo's version |
|---|---|---|
| `MISSION.md` | *Why* are we learning? What does success look like? What's out of scope? | Learn the craft, 2D top-down, GDScript, hobby pace — no shipping pressure |
| `NOTES.md` | *How* should lessons be taught? What's true of the environment? | One win per lesson; split-screen loop; Godot 4.6.2; the lesson design system |
| `learning-records/` | What has actually been learned? What decisions are locked? | Records 0001–0002: every lesson summarized, every decision logged |
| `RESOURCES.md` | Where does knowledge come from (instead of AI guesswork)? | Official Godot docs + community wisdom, each with a "use for" |
| `reference/` | What facts must stay pinned across many lessons? | WoW 1.12 combat values, researched once, cited by every combat lesson |
| `lessons/` | The actual teaching: one self-contained HTML page per win | 25 lessons + [`index.html`](lessons/index.html) to browse them |
| `projects/` | The real work, made by the learner's hands | A Godot project with click-targeting, a one-roll attack table, rage |
| `TELOS.md` | What is all of it *for*? (See "The telos discipline" below) | [`TELOS.md`](TELOS.md) |

The deep magic is `learning-records/`. After every session the teacher writes
down what was learned, what was decided, and — critically — what was *refused*
("do NOT re-suggest separating collision layers"). The next session reads it
first. That single habit converts a stateless chatbot into a teacher with a
year-long memory.

## The loop

Each session runs the same shape:

1. **Re-enter.** The teacher reads the mission, notes, and latest learning
   record. It proposes the next single win (or you ask for one).
2. **Teach.** It produces one lesson — tightly scoped, one new concept, every
   new term named — as a standalone page you keep forever.
3. **Do.** Split screen: lesson/terminal on the left, the real tool on the
   right. *You* perform every step. When something breaks, you report what you
   see; debugging your own mistake is half the lesson.
4. **Record.** The teacher appends to the learning record: what stuck, what
   was decided, what was deferred and *what would trigger it later*.

One win per session. The pace feels slow for a week and then suddenly you're
the person who built a Classic-accurate attack table and can explain every
band of it.

## Rules that earned their place

Each of these exists because skipping it caused a real failure:

- **One lesson, one win.** Two concepts per lesson is how understanding
  silently becomes recognition. Split, never stack.
- **The learner types everything.** The moment the AI pastes working systems
  into your project, you're back to being a spectator of your own hobby.
- **Give mechanics a story.** A throughline (here: find a sword → a wolf
  appears → a real fight → travel north) means every feature has a *reason*,
  and motivation survives the boring lessons.
- **Research once, pin it, cite it.** For any domain with real-world values,
  do one research spike into a reference doc. Lessons cite the doc. This kills
  the slow drift of plausible-but-wrong numbers.
- **Defer with a trigger, not a vibe.** "We'll generalize the equip system
  *when a second weapon exists*" is a plan. "We should refactor someday" is
  noise. Park refactors next to the thing that will trigger them.
- **Write down refusals.** Decisions you've already litigated go in the
  record, marked locked. Otherwise every session re-argues them.

## The telos discipline

Long projects drift. The fix here is a one-page [`TELOS.md`](TELOS.md) — the
*why behind the why* — plus a repeatable audit that regenerates it from
evidence (mission, records, git history) and scores recent work against it.

In this repo that audit is a Claude Code slash command:
[`.claude/commands/goal.md`](.claude/commands/goal.md). Run `/goal` and it
re-derives the telos, checks the last few commits for drift, and names the
smallest next step. Run `/goal <proposed work>` and it gives a verdict:
aligned, aligned-with-changes, or anti-telos. The most valuable section is
**anti-telos** — the things that would *look* like progress while betraying
the point (for this repo: an AI dumping finished systems, skipping ahead,
polishing the exhibit instead of learning).

## Start your own

1. Make a folder. Copy this structure: `MISSION.md`, `NOTES.md`,
   `RESOURCES.md`, empty `learning-records/`, `lessons/`, `reference/`, and a
   `projects/` (or equivalent) for the real work.
2. Fill the mission first. Minimum viable version:

   ```markdown
   # Mission: <subject>
   ## Why            — the honest reason, including past failures
   ## Success looks like — 3–4 observable outcomes, not vibes
   ## Constraints    — tools, pace, your actual starting level
   ## Out of scope   — what you are explicitly NOT doing yet
   ```

3. In `NOTES.md`, state how you want to be taught (lesson size, your level,
   your environment) — and keep it updated as you learn how you learn.
4. Open your AI tool in that folder and ask it to act as a stateful teacher:
   read the mission and notes, propose the first one-win lesson, and write a
   learning record at the end. Make it re-read the records at the start of
   every session. (With Claude Code, a `teach`-style skill or a short
   `CLAUDE.md` standing instruction does this automatically.)
5. After ~10 lessons, write your `TELOS.md` and add a `/goal`-style audit.
   You'll need it exactly when the project starts to feel busy instead of
   purposeful.

## What it produced here

Browse [`lessons/index.html`](lessons/index.html) for the full course this
process generated — from "what is a node" to a one-roll attack table with
miss, dodge, parry, glancing, crit, and rage, every value sourced from
Vanilla 1.12. The roadmap for lessons 26–33 (XP, inventory, quests, Heroic
Strike, Whirlwind) is in
[`learning-records/0002-roadmap-combat-quests-progression.md`](learning-records/0002-roadmap-combat-quests-progression.md).

The learner still writes every line.
