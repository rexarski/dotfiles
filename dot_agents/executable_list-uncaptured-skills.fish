#!/usr/bin/env fish
# List skill directories in ~/.agents/skills/ that are NOT tracked in .skill-lock.json.
# Anything listed here will be PRUNED by the next `skills` CLI run — move it
# into the rexarski/skills repo and reinstall: `skills add rexarski/skills -g -y`.

set -l lock ~/.agents/.skill-lock.json
set -l skills_dir ~/.agents/skills

if not test -f $lock
    echo "error: $lock not found" >&2
    exit 1
end
if not command -q jq
    echo "error: jq not on PATH" >&2
    exit 1
end

set -l tracked_file (mktemp -t skill-tracked.XXXXXX)
set -l local_file (mktemp -t skill-local.XXXXXX)

jq -r '.skills | keys[]' $lock | sort >$tracked_file
find $skills_dir -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort >$local_file

set -l uncaptured (comm -23 $local_file $tracked_file)
rm $tracked_file $local_file

if test (count $uncaptured) -eq 0
    echo "all local skills are tracked in .skill-lock.json"
else
    echo "local skills NOT in .skill-lock.json:"
    for s in $uncaptured
        echo "  $s"
    end
end
