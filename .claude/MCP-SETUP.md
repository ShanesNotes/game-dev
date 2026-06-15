# MCP servers for this repo

Project-scoped MCP servers are declared in `../.mcp.json` at the repo root, so any agent
working in this repo can use them after local environment variables are set.

## godot — editor & runtime control

Lets an agent launch the Godot editor, run the project in debug mode, capture console/debug
output, introspect the project (version, structure, scenes/nodes), build scenes and add nodes,
load sprites/textures, and manage 4.4+ resource UIDs (`get_uid`, `update_project_uids`).

- Source: https://github.com/Coding-Solo/godot-mcp
- Built from: a recent commit with 4.4+ UID tools (npm `0.1.1` was too old for this project).
- License: MIT
- Verified in this workspace: 2026-06-14 — responds to MCP `initialize` over stdio.

### Local setup

`.mcp.json` intentionally does **not** hard-code personal absolute paths. It runs
`tools/run-godot-mcp.sh`, which requires explicit local environment variables:

```bash
git clone https://github.com/Coding-Solo/godot-mcp ~/.local/share/godot-mcp
cd ~/.local/share/godot-mcp && npm install && npm run build

export GODOT_MCP_PATH="$HOME/.local/share/godot-mcp/build/index.js"
export GODOT_PATH="$HOME/.local/bin/godot"   # optional; defaults to `godot`
```

The wrapper refuses a missing or relative `GODOT_MCP_PATH`; this keeps the repo config
portable and makes the local trust boundary explicit.

### Updating

```bash
cd "$(dirname "$GODOT_MCP_PATH")/.." && git pull && npm install && npm run build
```
