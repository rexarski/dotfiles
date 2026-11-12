#!/bin/sh
# Write the names of this machine's installed Tinycast extensions to
# tinycast-extensions.txt (repo root). Run by .githooks/pre-commit; safe to
# run by hand. Settings, clipboard history and extension files stay untracked.
set -e

repo=$(cd "$(dirname "$0")/.." && pwd)
dir="$HOME/Library/Application Support/com.tinycast.app/extensions"
out="$repo/tinycast-extensions.txt"

[ -d "$dir" ] || { echo "tinycast-manifest: $dir not found, skipping" >&2; exit 0; }

{
  echo "# Tinycast extensions on the last machine that committed (generated, don't edit)."
  echo "# Reinstall by name from Tinycast's extension store."
  find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
} >"$out"
