# dotfiles (chezmoi source)

Managed by [chezmoi](https://www.chezmoi.io/). Source lives here; rendered
targets land under `~/`. This repo is **public** — see the secrets rules
in [CLAUDE.md](CLAUDE.md) before adding anything.

## Tracked files

```
~/.local/share/chezmoi/
├── README.md, CLAUDE.md                  repo docs (in .chezmoiignore, never applied)
├── scripts/                              repo-only helpers (in .chezmoiignore;
│   ├── update-skills.fish                  run from here, not rendered into ~/)
│   ├── list-uncaptured-skills.fish
│   ├── skills-manifest.sh                  writes skills.txt          ┐ run by
│   └── tinycast-manifest.sh                writes tinycast-extensions ┘ the hook
├── .githooks/                            repo-only (core.hooksPath)
│   ├── pre-commit                          refreshes + stages both manifests
│   └── commit-msg                          rejects non-conventional messages
├── skills.txt                            installed-skills snapshot (generated)
├── tinycast-extensions.txt               Tinycast extension names (generated)
├── dot_Brewfile                          → ~/.Brewfile   (curated bootstrap deps)
├── run_onchange_install-packages.sh.tmpl   runs `brew bundle --global` when
│                                           the Brewfile changes
├── dot_gitignore_global                  → ~/.gitignore_global (the only global
│                                           ignore; no ~/.config/git/ignore)
├── private_dot_gitconfig.tmpl            → ~/.gitconfig  (template; portable paths)
├── private_dot_npmrc                     → ~/.npmrc      (hardening: ignore-scripts,
│                                           min-release-age; no tokens here)
│
├── private_dot_ssh/                      → ~/.ssh/
│   ├── id_ed25519.pub                      signing pubkey (1Password holds the key)
│   └── allowed_signers                     lets `git log --show-signature` verify
│
├── dot_claude/                           → ~/.claude/
│   ├── executable_statusline-command.sh    (settings.json NOT tracked — apps
│   │                                         like Orca rewrite it)
│   └── hooks/executable_context-mode-cache-heal.mjs
│
├── dot_config/                           → ~/.config/
│   ├── private_fish/                       config.fish, fish_plugins, tide config,
│   │                                       functions/fish_greeting.fish, tips.txt
│   ├── fastfetch/greeting.jsonc            used by fish_greeting
│   ├── trmnl/create_private_meal_prep_webhook.tmpl  secret: read from
│   │                                         1Password once, on first create
│   ├── doom/                               Doom Emacs: init.el, config.el, packages.el
│   └── yazi/                               package.toml + theme.toml only — restore
│                                           plugins/flavors with `ya pkg install`
│
└── private_Library/…/com.mitchellh.ghostty/config
```

Not tracked on purpose: configs that apps rewrite themselves (zed,
`~/.claude/settings.json`, btop, gh, opencode, app `.plist`s), logs-only
dirs (mole, herdr), and generated trees (`~/.config/emacs`, yazi
plugins). They drift per machine and would only churn. Paths in tracked files use `$HOME` / `{{ .chezmoi.homeDir }}`,
never `/Users/<name>/`, and nothing branches on hostname.

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
git add -p; git commit; git push      # conventional commits (enforced by
                                      # .githooks/commit-msg), signed
```

On every other machine:

```fish
chezmoi update -v                     # git pull + apply in one step
# skills are not synced — pick what you want from skills.txt (see Skills)
```

`chezmoi update` fails politely if the local source repo is dirty — commit
or stash there first. If `apply` hits a prompt, follow the protocol above.

## Skills

Skills are **per machine, not synced**. chezmoi does not track
`~/.agents/.skill-lock.json`; instead every commit here regenerates
`skills.txt` — one `source<TAB>name` line per installed skill — so other
machines can install what they want:

```fish
grep -v '^#' ~/.local/share/chezmoi/skills.txt      # what the last machine had
skills add tw93/Waza -g -y -s hunt                   # install one
```

- `~/.agents/skills/` — real skill dirs, owned by the `skills` CLI.
- `~/.claude/skills/` — symlinks made by the CLI, plus two app-owned dirs
  to leave alone: `rex` (Rex terminal app) and `synced/` (claude.ai sync).
- Rex's and Orca's skills are left out of skills.txt: each app installs
  and updates its own on every machine.
- Upstream packs rename and drop skills, so `skills remove` can be
  one-way. Removing a skill locally is not "temporary".

Helper scripts (`scripts/`, not rendered into `~/`):

```fish
set src ~/.local/share/chezmoi
$src/scripts/update-skills.fish          # skills update, or per-skill refresh
$src/scripts/list-uncaptured-skills.fish # dirs not in the local lockfile
$src/scripts/skills-manifest.sh          # regenerate skills.txt by hand
```

## Tinycast

Only the extension **names** are recorded (`tinycast-extensions.txt`,
regenerated by the pre-commit hook). Reinstall the ones you want from
Tinycast's store. Its settings plist, clipboard history and the 100MB+
extension files are deliberately not tracked.

## Secrets

The repo is public. A secret lives in 1Password; the source holds only a
template that reads it at apply time:

```
{{ if lookPath "op" -}}
{{ onepasswordRead "op://Private/<item>/<field>" }}
{{ end -}}
```

- Create the source file **by hand** (`dot_config/…/create_private_X.tmpl`)
  — `chezmoi add` would copy the real secret into the repo.
- `create_` = only written when the target is missing. Once the file
  exists, `status`/`diff`/`apply` never call `op` (no Touch ID prompts).
  To pick up a rotated secret:
  `rm <target> && chezmoi apply --force <target>`.
- Verify: `chezmoi cat <target> | cmp - <target>` before committing.
- `op` comes from the Brewfile (`1password-cli`). Turn on 1Password →
  Settings → Developer → *Integrate with 1Password CLI* **before** the
  first apply on a machine — with `op` installed but not integrated, the
  template errors and the apply stops.
- Without `op` (e.g. Linux) the template renders empty and the file is
  simply not created.

Current secrets: `TRMNL meal prep webhook` (→ `~/.config/trmnl/meal_prep_webhook`).

## Linux

`.chezmoiignore` skips macOS-only targets (`Library/`, `.Brewfile`) when
`.chezmoi.os` isn't `darwin`, and the brew install script renders empty
there. Install fish/git/gh with the distro's package manager first.

## New machine bootstrap

```fish
# 1. Homebrew (https://brew.sh), then:
brew install chezmoi
chezmoi init --apply rexarski/dotfiles
#    └─ writes all configs AND runs run_onchange_install-packages:
#       brew bundle --global + npm install -g skills

# 2. enable the repo hooks (skills.txt refresh + conventional-commit check)
git -C ~/.local/share/chezmoi config core.hooksPath .githooks
ya pkg install                        # yazi plugins/flavors from package.toml

# 3. skills / Tinycast extensions (optional, selective)
skills add <source> -g -y -s <name>   # from skills.txt
#                                       tinycast-extensions.txt → Tinycast store
#    1Password secrets render once the CLI integration is on (see Secrets)

# 4. commit signing (see next section)
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
