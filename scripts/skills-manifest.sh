#!/bin/sh
# Write a plaintext snapshot of this machine's installed skills to
# skills.txt (repo root). Run by .githooks/pre-commit; safe to run by hand.
# The lockfile itself is NOT tracked — this file is the shareable record.
set -e

repo=$(cd "$(dirname "$0")/.." && pwd)
lock="$HOME/.agents/.skill-lock.json"
dir="$HOME/.agents/skills"
out="$repo/skills.txt"

# Skills an app installs and maintains itself (Orca, Rex) — never listed,
# whether the app or the skills CLI put them there.
app_owned='^(orca-|orchestration$|rex$)|^stablyai/orca	'

[ -f "$lock" ] || { echo "skills-manifest: $lock not found, skipping" >&2; exit 0; }
command -v jq >/dev/null || { echo "skills-manifest: jq not on PATH, skipping" >&2; exit 0; }

{
  echo "# Installed skills on the last machine that committed (generated, don't edit)."
  echo "# Install one:  skills add <source> -g -y -s <name>"
  echo "#"
  echo "# source	name"
  jq -r '.skills | to_entries[] | "\(.value.source)\t\(.key)"' "$lock" | sort |
    grep -Ev "$app_owned" || true
  # dirs the skills CLI doesn't own and no known app maintains: surface them
  if [ -d "$dir" ]; then
    jq -r '.skills | keys[]' "$lock" | sort >"$out.tracked"
    find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort |
      comm -23 - "$out.tracked" | grep -Ev "$app_owned" | sed 's/^/(app-installed)	/'
    rm -f "$out.tracked"
  fi
} >"$out"
