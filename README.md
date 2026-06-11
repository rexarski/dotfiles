# dotfiles (chezmoi source)

Managed by [chezmoi](https://www.chezmoi.io/). Source lives here; rendered
targets land under `~/`.

## Tracked files

```
~/.local/share/chezmoi/
├── README.md                                         (this file)
├── dot_gitignore_global                  → ~/.gitignore_global
├── private_dot_gitconfig                 → ~/.gitconfig
│
├── dot_agents/                           → ~/.agents/
│   ├── private_dot_skill-lock.json       → ~/.agents/.skill-lock.json
│   ├── executable_update-skills.fish     → ~/.agents/update-skills.fish
│   ├── executable_list-uncaptured-skills.fish
│   │                                     → ~/.agents/list-uncaptured-skills.fish
│   ├── executable_check-skill-symlinks.fish
│   │                                     → ~/.agents/check-skill-symlinks.fish
│   └── local-only-skills/                → ~/.agents/local-only-skills/
│       └── learn-quiz/                     (canonical home for local-only skills;
│                                            kept outside .agents/skills/ so the
│                                            `skills` CLI can't prune them)
│
├── dot_config/                           → ~/.config/
│   ├── btop/
│   │   └── btop.conf                     → ~/.config/btop/btop.conf
│   ├── gh/
│   │   ├── private_config.yml            → ~/.config/gh/config.yml
│   │   └── private_hosts.yml             → ~/.config/gh/hosts.yml
│   ├── private_fish/                     → ~/.config/fish/
│   │   ├── config.fish
│   │   ├── fish_plugins
│   │   └── executable_tide_config.fish
│   └── zed/
│       └── private_settings.json         → ~/.config/zed/settings.json
│
└── private_Library/                      → ~/Library/
    └── private_Application Support/
        └── com.mitchellh.ghostty/
            └── config                    (Ghostty terminal config)
```

Naming conventions:
- `dot_X`        → `.X`
- `private_X`    → file mode 0600
- `executable_X` → file mode 0755

## Daily workflow

### chezmoi

```fish
chezmoi diff                         # preview pending changes (source → target)
chezmoi apply                        # write source to target
chezmoi -v apply                     # verbose; shows per-file action
chezmoi re-add <path>                # pull a managed file back into source
chezmoi re-add --recursive ~/.agents # re-add everything under a managed dir
chezmoi cd                           # cd into the source dir (~/.local/share/chezmoi)
chezmoi managed                      # list every target path chezmoi owns
```

When `apply` prompts `diff/overwrite/all-overwrite/skip/quit`:
- Local edits you want to keep → **`quit`**, then `chezmoi re-add <path>`.
- Want to discard local edits → `overwrite`.

### skills library

Two source trees, one target:

- `~/.agents/skills/` — real dirs for **lockfile-tracked** skills (managed
  by the `skills` CLI).
- `~/.agents/local-only-skills/` — real dirs for **local-only** skills,
  kept outside `.agents/skills/` so the `skills` CLI can't prune them.
- `~/.claude/skills/<name>` — symlink to whichever source owns `<name>`.

```fish
# update all skills tracked in .skill-lock.json (recommended)
~/.agents/update-skills.fish

# per-skill refresh: remove + re-add from lockfile source
~/.agents/update-skills.fish hugo pdf

# raw CLI (operates on .agents/skills/, edits .skill-lock.json)
skills check          # check for available updates
skills update         # update everything (no per-skill arg)
skills list           # list installed
skills add <repo>     # add new skill pack from github
skills remove -s <name> -g -y
```

### local-only skills

Authored skills (not in any GitHub pack) live directly under
`~/.agents/local-only-skills/<name>/`. They get symlinked into
`~/.claude/skills/` like tracked skills, but the `skills` CLI never sees
them so they can't be pruned. To add one: create the dir, then run
`check-skill-symlinks.fish --link-missing` (or `--fix`).

```fish
# report drift (missing symlinks, leaked real dirs, wrong targets,
# and skills in .agents/skills/ that aren't lockfile-tracked)
~/.agents/check-skill-symlinks.fish

# flags
~/.agents/check-skill-symlinks.fish --help
#   --prune          delete orphan symlinks in .claude/skills/
#   --link-missing   create symlinks for skills lacking one in .claude/
#   --unlink-leaked  replace leaked real dirs in .claude/skills/ with
#                    symlinks (rm -rf the .claude/ copy, trust source)
#   --fix            all three remediations

# audit: any skill in .agents/skills/ NOT in the lockfile is drift —
# move it into local-only-skills/ before the next `skills` run
~/.agents/list-uncaptured-skills.fish
```

### new machine bootstrap

```fish
chezmoi init <repo-url>             # clone source repo
chezmoi apply                       # write files (no skills yet)
brew install skills jq              # CLI deps
~/.agents/update-skills.fish        # materialize lockfile-tracked skills
~/.agents/check-skill-symlinks.fish --fix
                                    # symlink everything from both source
                                    # trees into ~/.claude/skills/
```
