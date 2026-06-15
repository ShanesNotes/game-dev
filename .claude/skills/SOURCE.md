# Godot skills — provenance

These 48 skills (`<name>/SKILL.md`) and the 9 agents in `../agents/` are vendored from
**GodotPrompter** — an agentic skills framework for Godot 4.x game development.

- Source: https://github.com/jame581/GodotPrompter
- Version: v1.9.0 (commit `e09aa6d`)
- Author: Jan Mesarc
- License: MIT (see `.godot-prompter-LICENSE`)
- Vendored: 2026-06-14

## Why these live here (committed, not a plugin install)

They sit in the repo's `.claude/skills/` and `.claude/agents/` so that **every agent working
in this repo auto-discovers them** — no per-machine plugin install required. Invoke a skill by
its bare name (e.g. `state-machine`, `inventory-system`, `godot-testing`), not the
`godot-prompter:` plugin namespace.

## Not vendored (deliberate)

GodotPrompter's `.claude/settings.json` ships a `PostToolUse` hook
(`scripts/hooks/validate-skill-on-edit.mjs`) that would fire on every Edit/Write in this repo
and reference a script we didn't copy. It was intentionally left out.

## Stack note

The skills are GDScript-first (GDScript shown, then C#). Two are C#-only and a mismatch for this
repo's GDScript stack — delete if unwanted: `csharp-godot/`, `csharp-signals/`, and the
`../agents/godot-csharp-engineer.md` agent.

## Updating

Re-clone the source and re-copy `skills/` + `agents/`, or track upstream releases at the URL above.
