#!/usr/bin/env fish
# Verify the symlink invariant between ~/.agents/skills/ (real) and
# ~/.claude/skills/ (symlinks → .agents/skills/<name>), AND back up /
# restore local-only skills against ~/.agents/local-only-skills/.
#
# Reports four classes of drift:
#   1. Missing symlinks   — a skill exists in .agents/ but not in .claude/
#   2. Orphan entries     — symlink in .claude/ whose target no longer exists
#                           in .agents/skills/ (the `skills` CLI sometimes
#                           prunes lockfile-untracked dirs and leaves these)
#   3. Non-symlinks       — entry in .claude/ is a real dir/file (leaked back)
#   4. Wrong target       — symlink in .claude/ resolves to something other
#                           than ~/.agents/skills/<same-name> (compared via
#                           realpath, so relative vs absolute is fine)
#
# Local-only skills (in .agents/skills/ but NOT in .skill-lock.json) are
# vulnerable to `skills` CLI prunes. Each run this script:
#   • rsyncs every local-only skill to ~/.agents/local-only-skills/<name>/
#   • detects skills present in local-only-skills/ but missing from
#     .agents/skills/ — these were pruned. Prompts to restore.
#
# Usage:
#   ./check-skill-symlinks.fish                  # report + backup + interactive restore prompt
#   ./check-skill-symlinks.fish --prune          # delete orphan symlinks
#   ./check-skill-symlinks.fish --link-missing   # create symlinks for missing skills
#   ./check-skill-symlinks.fish --fix            # --prune and --link-missing
#   ./check-skill-symlinks.fish --yes            # auto-confirm restore prompt
#   ./check-skill-symlinks.fish --no-backup      # skip backup pass
#   ./check-skill-symlinks.fish --no-restore     # skip restore detection
#   ./check-skill-symlinks.fish --help

set -l agents ~/.agents/skills
set -l claude ~/.claude/skills
set -l local_only ~/.agents/local-only-skills
set -l lock ~/.agents/.skill-lock.json

set -l do_prune 0
set -l do_link 0
set -l auto_yes 0
set -l do_backup 1
set -l do_restore 1

for arg in $argv
    switch $arg
        case --help -h
            sed -n '2,30p' (status filename)
            exit 0
        case --prune
            set do_prune 1
        case --link-missing
            set do_link 1
        case --fix
            set do_prune 1
            set do_link 1
        case --yes -y
            set auto_yes 1
        case --no-backup
            set do_backup 0
        case --no-restore
            set do_restore 0
        case '*'
            echo "unknown flag: $arg (try --help)" >&2
            exit 2
    end
end

if not test -d $agents
    echo "error: $agents not found" >&2
    exit 1
end
if not test -d $claude
    echo "error: $claude not found" >&2
    exit 1
end

# ---------- symlink check ----------

set -l missing
set -l orphans
set -l non_symlinks
set -l wrong_target

for d in $agents/*/
    set -l name (basename $d)
    set -l link "$claude/$name"
    if not test -L $link
        if not test -e $link
            set missing $missing $name
        end
        continue
    end
    set -l resolved (realpath $link 2>/dev/null)
    set -l expected (realpath "$agents/$name")
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

set -l total_drift (math (count $missing) + (count $orphans) + (count $non_symlinks) + (count $wrong_target))

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

function _report_info
    set -l label $argv[1]
    set -l items $argv[2..-1]
    if test (count $items) -eq 0
        echo "  · $label: none"
    else
        echo "  → $label: "(count $items)
        for i in $items
            echo "      $i"
        end
    end
end

echo "skill symlink check"
echo "  .agents/skills: "(count $agents/*/)" dirs"
echo "  .claude/skills: "(count $claude/*)" entries"
echo
_report "missing symlinks (in .agents/, absent from .claude/)" $missing
_report "orphans (symlink in .claude/ with no .agents/ target)" $orphans
_report "non-symlinks in .claude/ (leaked real files/dirs)" $non_symlinks
_report "wrong target" $wrong_target
echo

# ---------- symlink remediation ----------

if test $do_prune -eq 1; and test (count $orphans) -gt 0
    echo "--prune: removing orphan symlinks"
    for name in $orphans
        rm "$claude/$name"
        echo "      rm $claude/$name"
    end
end

if test $do_link -eq 1; and test (count $missing) -gt 0
    echo "--link-missing: creating symlinks"
    for name in $missing
        ln -s "$HOME/.agents/skills/$name" "$claude/$name"
        echo "      ln -s $HOME/.agents/skills/$name $claude/$name"
    end
end

# ---------- local-only backup + restore ----------

set -l backed_up
set -l prunable

if test $do_backup -eq 1; or test $do_restore -eq 1
    if not command -q jq
        echo "skipping local-only pass: jq not installed"
    else if not test -f $lock
        echo "skipping local-only pass: $lock not found"
    else
        mkdir -p $local_only
        set -l tracked (jq -r '.skills | keys[]' $lock | sort)

        # backup: every dir in .agents/skills/ NOT in lockfile → mirror into local_only
        if test $do_backup -eq 1
            for d in $agents/*/
                set -l name (basename $d)
                if not contains $name $tracked
                    rsync -a --delete "$d" "$local_only/$name/"
                    set backed_up $backed_up $name
                end
            end
        end

        # restore detection: anything in local_only/ that's missing from .agents/skills/
        if test $do_restore -eq 1; and test -d $local_only
            for d in $local_only/*/
                set -l name (basename $d)
                if not test -d "$agents/$name"
                    set prunable $prunable $name
                end
            end
        end
    end
end

echo "local-only skills"
_report_info "backed up to $local_only/" $backed_up
_report "previously backed up but MISSING from .agents/skills/ (likely pruned)" $prunable
echo

# ---------- restore prompt ----------

if test (count $prunable) -gt 0
    set -l answer ""
    if test $auto_yes -eq 1
        set answer y
        echo "--yes: auto-restoring "(count $prunable)" pruned skill(s)"
    else if isatty stdin
        read -P "restore "(count $prunable)" pruned skill(s) into .agents/skills/? [y/N] " answer
    else
        echo "non-interactive shell; rerun with --yes to restore"
    end

    if test "$answer" = y; or test "$answer" = Y; or test "$answer" = yes
        for name in $prunable
            cp -R "$local_only/$name" "$agents/$name"
            echo "      restored $name"
            if not test -L "$claude/$name"
                ln -s "$HOME/.agents/skills/$name" "$claude/$name"
                echo "      linked .claude/skills/$name"
            end
        end
        echo "rerun without flags to verify"
        exit 0
    end
end

# ---------- exit ----------

if test $do_prune -eq 1; or test $do_link -eq 1
    echo "rerun without flags to verify"
    exit 0
end

if test $total_drift -eq 0
    echo "all clean"
    exit 0
else
    echo "drift detected: $total_drift issue(s)"
    echo "hint: --prune (orphans), --link-missing (missing), --fix (both)"
    exit 1
end
