# MCP servers for this repo

Project-scoped MCP servers are declared in `../.mcp.json` at the repo root, so any agent
working in this repo can use them.

## godot — editor & runtime control

Lets an agent launch the Godot editor, run the project in debug mode, capture console/debug
output, introspect the project (version, structure, scenes/nodes), build scenes and add nodes,
load sprites/textures, and manage 4.4+ resource UIDs (`get_uid`, `update_project_uids`).

- Source: https://github.com/Coding-Solo/godot-mcp
- Built from: commit `1209744` (GitHub HEAD, Apr 2026 — newer than npm `0.1.1`, which lacked
  the 4.4+ UID tools the Godot 4.6 project needs)
- Installed at: `/home/ark/.local/share/godot-mcp` (`build/index.js`)
- Godot binary: `/home/ark/.local/bin/godot` (4.6.2-stable mono), set via `GODOT_PATH`
- License: MIT
- Verified: 2026-06-14 — responds to MCP `initialize` over stdio, resolves the Godot binary.

### ⚠️ Machine-specific paths

`.mcp.json` hard-codes two absolute paths (the built server and the Godot binary). On a different
machine you must:

1. Clone + build the server:
   ```
   git clone https://github.com/Coding-Solo/godot-mcp ~/.local/share/godot-mcp
   cd ~/.local/share/godot-mcp && npm install && npm run build
   ```
2. Point `args[0]` at that `build/index.js` and `GODOT_PATH` at your Godot 4.x binary.

### Updating

`cd ~/.local/share/godot-mcp && git pull && npm install && npm run build`
