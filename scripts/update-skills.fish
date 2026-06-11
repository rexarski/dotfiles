#!/usr/bin/env fish
# Update skills tracked in ~/.agents/.skill-lock.json via the `skills` CLI.
# Usage:
#   ./update-skills.fish              # `skills update` — updates ALL tracked skills
#   ./update-skills.fish <name> ...   # per-skill: remove + re-add from lockfile source
#
# Per-skill mode is a workaround: the `skills` CLI's `update` subcommand has no
# per-skill granularity, so we look up each skill's source in .skill-lock.json
# and do `skills remove -g -s <name> -y && skills add <source> -g -s <name> -y`.

set -l lock ~/.agents/.skill-lock.json

if not command -q skills
    echo "error: 'skills' CLI not on PATH" >&2
    exit 1
end
if not test -f $lock
    echo "error: $lock not found" >&2
    exit 1
end

set -l backup (mktemp -t skill-lock.XXXXXX)
cp $lock $backup

if test (count $argv) -eq 0
    skills update
    set -l rc $status
    if test $rc -ne 0
        echo "skills update exited $rc; lockfile preserved" >&2
        rm $backup
        exit $rc
    end
else
    if not command -q jq
        echo "error: jq required for per-skill mode" >&2
        rm $backup
        exit 1
    end
    for name in $argv
        set -l source (jq -r --arg n $name '.skills[$n].source // empty' $lock)
        if test -z "$source"
            echo "skip: '$name' not in lockfile" >&2
            continue
        end
        echo "→ refreshing $name from $source"
        skills remove -g -s $name -y; and skills add $source -g -s $name -y
        or begin
            echo "failed to refresh $name; lockfile preserved" >&2
            rm $backup
            exit 1
        end
    end
end

if diff -q $backup $lock >/dev/null
    echo "no lockfile changes"
else
    echo "lockfile changed:"
    diff -u $backup $lock
end
rm $backup
