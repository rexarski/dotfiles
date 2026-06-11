#!/usr/bin/env fish
# Verify the symlink invariant between two source trees and ~/.claude/skills/.
#
# Source trees (real dirs):
#   ~/.agents/skills/             — lockfile-tracked skills (managed by `skills` CLI)
#   ~/.agents/local-only-skills/  — local-only skills, kept here so the
#                                   `skills` CLI can't prune them
#
# Target tree (symlinks only):
#   ~/.claude/skills/<name>  →  whichever source owns <name>
#
# Reports five classes of drift:
#   1. Missing symlinks   — a skill exists in a source but not in .claude/
#   2. Orphan entries     — symlink in .claude/ whose target no longer exists
#   3. Non-symlinks       — entry in .claude/ is a real dir/file (leaked back)
#   4. Wrong target       — symlink in .claude/ resolves to something other
#                           than the matching source/<same-name>
#   5. Untracked in       — skill in .agents/skills/ that is NOT in the
#      .agents/skills/      lockfile. Vulnerable to `skills` CLI prune.
#                           Move it to ~/.agents/local-only-skills/.
#
# Usage:
#   ./check-skill-symlinks.fish                  # report only
#   ./check-skill-symlinks.fish --prune          # delete orphan symlinks
#   ./check-skill-symlinks.fish --link-missing   # create symlinks for missing skills
#   ./check-skill-symlinks.fish --unlink-leaked  # replace leaked real dirs with symlinks
#                                                # (rm -rf the .claude/ copy, trust source)
#   ./check-skill-symlinks.fish --fix            # all three remediations
#   ./check-skill-symlinks.fish --help

set -l agents ~/.agents/skills
set -l local_only ~/.agents/local-only-skills
set -l claude ~/.claude/skills
set -l lock ~/.agents/.skill-lock.json

set -l do_prune 0
set -l do_link 0
set -l do_unlink_leaked 0

for arg in $argv
    switch $arg
        case --help -h
            sed -n '2,29p' (status filename)
            exit 0
        case --prune
            set do_prune 1
        case --link-missing
            set do_link 1
        case --unlink-leaked
            set do_unlink_leaked 1
        case --fix
            set do_prune 1
            set do_link 1
            set do_unlink_leaked 1
        case '*'
            echo "unknown flag: $arg (try --help)" >&2
            exit 2
    end
end

for d in $agents $local_only $claude
    if not test -d $d
        echo "error: $d not found" >&2
        exit 1
    end
end

# ---------- build name → source map ----------

set -l names
set -l sources
set -l duplicates

for d in $agents/*/
    set -l name (basename $d)
    set names $names $name
    set sources $sources $agents
end

for d in $local_only/*/
    set -l name (basename $d)
    if contains $name $names
        set duplicates $duplicates $name
        continue
    end
    set names $names $name
    set sources $sources $local_only
end

# ---------- drift detection ----------

set -l missing
set -l missing_sources
set -l orphans
set -l non_symlinks
set -l wrong_target

for i in (seq (count $names))
    set -l name $names[$i]
    set -l source $sources[$i]
    set -l link "$claude/$name"
    if not test -L $link
        if not test -e $link
            set missing $missing $name
            set missing_sources $missing_sources $source
        end
        continue
    end
    set -l resolved (realpath $link 2>/dev/null)
    set -l expected (realpath "$source/$name")
    if test "$resolved" != "$expected"
        set wrong_target $wrong_target "$name (→ "(readlink $link)")"
    end
end

for entry in $claude/*
    set -l name (basename $entry)
    if not test -L $entry
        set non_symlinks $non_symlinks $name
        continue
    end
    set -l resolved (realpath $entry 2>/dev/null)
    if test -z "$resolved"; or not test -d $resolved
        set orphans $orphans $name
    end
end

# ---------- validation: untracked skills in .agents/skills/ ----------

set -l untracked_in_agents
if command -q jq; and test -f $lock
    set -l tracked (jq -r '.skills | keys[]' $lock | sort)
    for d in $agents/*/
        set -l name (basename $d)
        if not contains $name $tracked
            set untracked_in_agents $untracked_in_agents $name
        end
    end
end

# ---------- report ----------

function _report
    set -l label $argv[1]
    set -l items $argv[2..-1]
    if test (count $items) -eq 0
        echo "  ✓ $label: none"
    else
        echo "  ✗ $label: "(count $items)
        for i in $items
            echo "      $i"
        end
    end
end

echo "skill symlink check"
echo "  .agents/skills:            "(count $agents/*/)" dirs (lockfile-tracked)"
echo "  .agents/local-only-skills: "(count $local_only/*/)" dirs (local-only)"
echo "  .claude/skills:            "(count $claude/*)" entries (should all be symlinks)"
echo
_report "missing symlinks (in a source, absent from .claude/)" $missing
_report "orphans (symlink in .claude/ with no source target)" $orphans
_report "non-symlinks in .claude/ (leaked real files/dirs)" $non_symlinks
_report "wrong target" $wrong_target
_report "untracked in .agents/skills/ (move to local-only-skills/ to avoid prune)" $untracked_in_agents
if test (count $duplicates) -gt 0
    _report "name collisions (in both source trees)" $duplicates
end
echo

set -l total_drift (math (count $missing) + (count $orphans) + (count $non_symlinks) + (count $wrong_target))

# ---------- remediation ----------

if test $do_prune -eq 1; and test (count $orphans) -gt 0
    echo "--prune: removing orphan symlinks"
    for name in $orphans
        rm "$claude/$name"
        echo "      rm $claude/$name"
    end
end

if test $do_link -eq 1; and test (count $missing) -gt 0
    echo "--link-missing: creating symlinks"
    for i in (seq (count $missing))
        set -l name $missing[$i]
        set -l source $missing_sources[$i]
        ln -s "$source/$name" "$claude/$name"
        echo "      ln -s $source/$name $claude/$name"
    end
end

if test $do_unlink_leaked -eq 1; and test (count $non_symlinks) -gt 0
    echo "--unlink-leaked: replacing leaked real dirs with symlinks"
    for name in $non_symlinks
        # Find matching source
        set -l source ""
        for i in (seq (count $names))
            if test "$names[$i]" = "$name"
                set source $sources[$i]
                break
            end
        end
        if test -z "$source"
            echo "      SKIP $name (no source — leaked dir has no owner; remove manually)"
            continue
        end
        rm -rf "$claude/$name"
        ln -s "$source/$name" "$claude/$name"
        echo "      replaced $claude/$name → $source/$name"
    end
end

# ---------- exit ----------

if test $do_prune -eq 1; or test $do_link -eq 1; or test $do_unlink_leaked -eq 1
    echo "rerun without flags to verify"
    exit 0
end

if test $total_drift -eq 0
    echo "all clean"
    exit 0
else
    echo "drift detected: $total_drift issue(s)"
    echo "hint: --prune (orphans), --link-missing (missing), --unlink-leaked (leaked dirs), --fix (all)"
    exit 1
end
