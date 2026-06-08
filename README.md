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
│       └── learn-quiz/                     (canonical backup of local-only skills;
│                                            survives `skills` CLI prunes)
│
├── dot_config/                           → ~/.config/
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

`~/.agents/skills/` is the canonical skill library (real dirs).
`~/.claude/skills/` is symlinks pointing into it.

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

Skills authored locally (not in any GitHub pack) are vulnerable to `skills`
CLI prunes since they aren't in the lockfile. Workflow:

```fish
# list skills present in .agents/skills/ but NOT in .skill-lock.json
~/.agents/list-uncaptured-skills.fish

# verify symlink integrity, backup local-only skills,
# and prompt to restore anything that was pruned
~/.agents/check-skill-symlinks.fish

# non-interactive auto-restore
~/.agents/check-skill-symlinks.fish --yes

# flags
~/.agents/check-skill-symlinks.fish --help
#   --prune          delete orphan symlinks in .claude/skills/
#   --link-missing   create symlinks for skills lacking one in .claude/
#   --fix            both of the above
#   --yes            auto-confirm the restore prompt
#   --no-backup      skip backing up local-only skills
#   --no-restore     skip restore detection
```

### new machine bootstrap

```fish
chezmoi init <repo-url>             # clone source repo
chezmoi apply                       # write files (no skills yet)
brew install skills jq rsync        # CLI deps
~/.agents/update-skills.fish        # materialize all 38 tracked skills
~/.agents/check-skill-symlinks.fish --fix --yes
                                    # restore local-only skills from backup,
                                    # fix any symlink drift
```
