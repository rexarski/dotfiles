# dotfiles (chezmoi source)

Managed by [chezmoi](https://www.chezmoi.io/). Source lives here; rendered
targets land under `~/`. This repo is **public** — see the secrets rules
in [CLAUDE.md](CLAUDE.md) before adding anything.

Authored agent skills live in a separate repo:
[rexarski/skills](https://github.com/rexarski/skills) (see “skills” below).

## Tracked files

```
~/.local/share/chezmoi/
├── README.md, CLAUDE.md                  repo docs (in .chezmoiignore, never applied)
├── scripts/                              repo-only helpers (in .chezmoiignore;
│   ├── update-skills.fish                  run from here, not rendered into ~/)
│   └── list-uncaptured-skills.fish
├── dot_Brewfile                          → ~/.Brewfile   (curated bootstrap deps)
├── run_onchange_install-packages.sh.tmpl   runs `brew bundle --global` when
│                                           the Brewfile changes
├── dot_gitignore_global                  → ~/.gitignore_global
├── private_dot_gitconfig.tmpl            → ~/.gitconfig  (template; portable paths)
│
├── private_dot_ssh/                      → ~/.ssh/
│   ├── id_ed25519.pub                      signing pubkey (1Password holds the key)
│   └── allowed_signers                     lets `git log --show-signature` verify
│
├── dot_agents/                           → ~/.agents/
│   └── private_dot_skill-lock.json         pins every installed skill
│
├── dot_claude/                           → ~/.claude/
│   ├── private_settings.json               hooks, plugins, statusline config
│   ├── executable_statusline-command.sh
│   └── hooks/executable_context-mode-cache-heal.mjs
│
├── dot_config/                           → ~/.config/
│   ├── btop/btop.conf                      (save_config_on_exit off — keep it so)
│   ├── gh/private_config.yml               (hosts.yml deliberately NOT tracked)
│   ├── private_fish/                       config.fish, fish_plugins, tide config
│   └── zed/private_settings.json
│
└── private_Library/…/com.mitchellh.ghostty/config
```

Naming conventions: `dot_X` → `.X` · `private_X` → mode 0600 ·
`executable_X` → mode 0755 · `X.tmpl` → rendered Go template.

## Daily workflow

```fish
chezmoi diff                         # preview pending changes (source → target)
chezmoi -v apply                     # write source to target, verbose
chezmoi re-add <path>                # pull a locally-edited target back into source
chezmoi add <path>                   # start tracking a new file
chezmoi forget <path>                # stop tracking (leaves target intact)
chezmoi cd                           # cd into this source dir
chezmoi managed                      # list every target chezmoi owns
```

When `apply` prompts `diff/overwrite/all-overwrite/skip/quit`:
- Local edits you want to keep → **`quit`**, then `chezmoi re-add <path>`.
- Want to discard local edits → `overwrite`.

## Keeping machines in sync

On the machine where you made changes:

```fish
chezmoi cd
git add -p; git commit; git push      # conventional commits, signed
```

On every other machine:

```fish
chezmoi update -v                     # git pull + apply in one step
~/.local/share/chezmoi/scripts/update-skills.fish   # if .skill-lock.json changed
```

`chezmoi update` fails politely if the local source repo is dirty — commit
or stash there first. If `apply` hits a prompt, follow the protocol above.

## Skills

Everything is lockfile-tracked — there is no separate “local-only” tree.

- `~/.agents/skills/` — real skill dirs, owned by the `skills` CLI. It
  **prunes anything not in `.skill-lock.json`**, which is fine because
  every skill (including authored ones) comes from a tracked repo.
- Authored ("local-only") skills live in
  [rexarski/skills](https://github.com/rexarski/skills)
  (local clone: `~/Developer/skills`). **To load them on any machine:**

  ```fish
  skills add rexarski/skills -g -y
  ```

  That installs them into `~/.agents/skills/`, records them in the
  lockfile, and symlinks them into each agent's skill dir — same as any
  third-party pack.
- `~/.claude/skills/` etc. — symlinks, created and maintained by the
  `skills` CLI itself.

Helper scripts live in this repo (`scripts/`, not rendered into `~/`):

```fish
set src ~/.local/share/chezmoi

# reinstall/refresh everything in the lockfile
$src/scripts/update-skills.fish       # or a subset: update-skills.fish hugo pdf

# raw CLI
skills check / update / list
skills add <owner>/<repo> -g -y
skills remove -s <name> -g -y

# drift audit: anything listed here would be pruned on the next CLI run —
# it belongs in rexarski/skills (or another pack) instead
$src/scripts/list-uncaptured-skills.fish
```

Author or edit a skill:

```fish
cd ~/Developer/skills                 # edit skills/<name>/SKILL.md
git add -A; git commit; git push
skills add rexarski/skills -g -y      # refresh installed copy
chezmoi re-add ~/.agents/.skill-lock.json   # commit lockfile change here
```

## New machine bootstrap

```fish
# 1. Homebrew (https://brew.sh), then:
brew install chezmoi
chezmoi init --apply rexarski/dotfiles
#    └─ writes all configs AND runs run_onchange_install-packages:
#       brew bundle --global + npm install -g skills

# 2. skills
~/.local/share/chezmoi/scripts/update-skills.fish
#                                     # materialize every lockfile-tracked skill
skills add rexarski/skills -g -y      # ensure authored (local-only) skills load

# 3. commit signing (see next section)
```

## Commit signing on a new machine

Commits are SSH-signed via 1Password's `op-ssh-sign`. The gitconfig is a
template — pubkey paths render against `{{ .chezmoi.homeDir }}` per machine.

1. Install + sign in to 1Password; enable `Developer → Use the SSH agent`.
2. `~/.ssh/id_ed25519.pub` and `~/.ssh/allowed_signers` are already written
   by `chezmoi apply` (public info, safe in source).
3. Verify:
   ```fish
   cd ~/.local/share/chezmoi
   git commit --allow-empty -m "test: signing"
   git log --show-signature -1     # expect: Good "git" signature
   git reset --hard HEAD^
   ```

If the pubkey rotates:

```fish
set sock ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
env SSH_AUTH_SOCK=$sock ssh-add -L | grep '^ssh-ed25519' > ~/.ssh/id_ed25519.pub
awk '{print "rexarski@gmail.com " $0}' ~/.ssh/id_ed25519.pub > ~/.ssh/allowed_signers
chezmoi re-add ~/.ssh/id_ed25519.pub ~/.ssh/allowed_signers
```
