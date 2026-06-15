#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GODOT_MCP_PATH:-}" ]]; then
  echo "GODOT_MCP_PATH must point to a built godot-mcp build/index.js" >&2
  exit 64
fi

if [[ "${GODOT_MCP_PATH}" != /* ]]; then
  echo "GODOT_MCP_PATH must be an absolute path: ${GODOT_MCP_PATH}" >&2
  exit 64
fi

if [[ ! -f "${GODOT_MCP_PATH}" ]]; then
  echo "GODOT_MCP_PATH does not exist: ${GODOT_MCP_PATH}" >&2
  exit 66
fi

if [[ -z "${GODOT_PATH:-}" ]]; then
  export GODOT_PATH="godot"
elif [[ "${GODOT_PATH}" == /* && ! -x "${GODOT_PATH}" ]]; then
  echo "GODOT_PATH is not executable: ${GODOT_PATH}" >&2
  exit 66
fi

exec node "${GODOT_MCP_PATH}"
