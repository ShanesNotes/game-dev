# Godot skills — provenance

These 46 skills (`<name>/SKILL.md`) and the 8 agents in `../agents/` are vendored from
**GodotPrompter** — an agentic skills framework for Godot 4.x game development.
(Upstream ships 48 skills + 9 agents; the C#-only ones were pruned — see "Stack note" below.)

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

The skills are GDScript-first (GDScript shown, then C#). The C#-only items from upstream were
pruned for this repo's GDScript stack: the `csharp-godot` and `csharp-signals` skills and the
`godot-csharp-engineer` agent. All cross-references to them in the remaining skills/agents
("Related skills" / "Routing" hints, scripting-doc lists) were scrubbed.

## Updating

Re-clone the source and re-copy `skills/` + `agents/`, or track upstream releases at the URL above.
