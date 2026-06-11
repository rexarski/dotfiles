# Maintenance notes for this chezmoi source repo

This directory is the **source** for chezmoi; files render into `~/` via
`chezmoi apply`. Do not confuse source paths with target paths. Workflows
and commands live in [README.md](README.md) — this file is invariants only.

## Source ↔ target

| source name in this repo            | target path           |
| ----------------------------------- | --------------------- |
| `dot_X`                             | `~/.X`                |
| `private_X`                         | mode 0600             |
| `executable_X`                      | mode 0755             |
| `X.tmpl`                            | rendered Go template  |
| `private_Library/private_App.../X`  | `~/Library/App.../X`  |

`chezmoi add` picks prefixes automatically — never hand-name. Templates:
`chezmoi add --template`, or rename to `.tmpl` after.

## Editing flow (pick one direction)

- Source → target: edit here, then `chezmoi diff && chezmoi apply`.
- Target → source: `chezmoi re-add <target>`.
- Never edit both sides by hand. If `apply` prompts
  `diff/overwrite/.../quit`, the target is newer: **quit, then re-add**.
  `overwrite` discards the local edit.

## Secrets (this repo is PUBLIC)

- Never track `~/.config/gh/hosts.yml` — gh writes oauth tokens into it
  when keychain storage is unavailable. It was deliberately forgotten.
- `private_` controls file mode only; it does not encrypt or hide content
  from git. No API keys / tokens in any tracked file, ever.
- Before `chezmoi re-add` of any config an app rewrites (gh, zed, etc.),
  skim the diff for injected credentials.
- Secret-bearing configs need `chezmoi secret` / 1Password template
  lookups, not plain files.

## Skills invariant

All skills are lockfile-tracked; there is no local-only tree anymore.

- `~/.agents/skills/` is owned by the `skills` CLI: it **prunes any dir
  not in `.skill-lock.json`**. Never place authored skills there directly.
- Authored skills belong in the
  [rexarski/skills](https://github.com/rexarski/skills) repo
  (clone: `~/Developer/skills`), installed via `skills add rexarski/skills`.
- `~/.claude/skills/` must contain only symlinks (the CLI manages them).
  Never write real files/dirs into it.
- After any `skills` CLI operation:
  `scripts/list-uncaptured-skills.fish` (in this repo) must report zero
  uncaptured skills, then `chezmoi re-add ~/.agents/.skill-lock.json`.
- Helper scripts live in `scripts/` here — repo-only, listed in
  `.chezmoiignore`, never rendered into `~/`. Don't re-add them to
  `dot_agents/`.

## Commit signing

`private_dot_gitconfig.tmpl` uses `{{ .chezmoi.homeDir }}` for the
signingkey/excludesfile paths so they render on any machine. Do **not**
hardcode `/Users/<name>/` in it. Signing chain: git → `op-ssh-sign` →
1Password agent. Pubkey + allowed_signers are tracked (public info);
the private key never leaves 1Password.

## Churn guards

- `dot_config/btop/btop.conf` sets `save_config_on_exit = False` so btop
  doesn't rewrite the target on every exit. Keep that line.
- `.skill-lock.json` diffs in `lastSelectedAgents` are CLI noise, not
  real change — fine to commit with the next lockfile update.

## Keep the README in sync

README.md is the human reference. In the same commit: tracked-file
changes → update the tree; helper/flag changes → update workflows;
bootstrap changes (new dep, new init step) → update the bootstrap block.

## Don't

- Don't run `git` inside `~/` — only in this source dir (`chezmoi cd`).
- Don't commit without conventional-commit messages.
- Don't `rm` anything in `~/.claude/skills/` without confirming it's an
  orphan symlink.
- Don't track high-churn or secret-prone files without a churn/secret
  guard (see above).
