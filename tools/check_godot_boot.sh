#!/usr/bin/env bash
set -euo pipefail

runs="${1:-3}"
if ! [[ "$runs" =~ ^[0-9]+$ ]] || [[ "$runs" -lt 1 ]]; then
  echo "usage: $0 [positive-run-count]" >&2
  exit 64
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pattern='SCRIPT ERROR|ERROR:|WARNING:'

for i in $(seq 1 "$runs"); do
  log="${TMPDIR:-/tmp}/game-dev-boot-${i}-$$.log"
  godot --headless --audio-driver Dummy --path "$repo_root/projects/first-steps" res://main.tscn --quit-after 120 2>&1 | tee "$log"
  if grep -E "$pattern" "$log"; then
    echo "boot smoke failed on run $i; see $log" >&2
    exit 1
  fi
  rm -f "$log"
done
