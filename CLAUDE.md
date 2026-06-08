# Maintenance notes for this chezmoi source repo

This directory is the **source** for chezmoi. Files here render into `~/`
via `chezmoi apply`. Do not confuse source paths with target paths.

## Source ↔ target

| source name in this repo            | target path           |
| ----------------------------------- | --------------------- |
| `dot_X`                             | `~/.X`                |
| `private_X`                         | mode 0600             |
| `executable_X`                      | mode 0755             |
| `dot_agents/foo.fish`               | `~/.agents/foo.fish`  |
| `private_Library/private_App.../X`  | `~/Library/App.../X`  |

When adding a new file with `chezmoi add ~/.some/file`, chezmoi picks the
prefix automatically — do not hand-name.

## Editing flow

- **Source → target** (the normal direction):
  edit a file here, then `chezmoi diff && chezmoi apply`.
- **Target → source** (you edited `~/.X` directly):
  `chezmoi re-add ~/.X` pulls the change back into source.
- **Never** edit a target and then also edit source by hand — pick one
  direction and use the right command, or the next `apply` will prompt
  `overwrite/skip` and you'll lose work.

When `chezmoi apply` prompts `diff/overwrite/all-overwrite/skip/quit`:
the local edit is newer than source. **Quit, then `chezmoi re-add`** to
preserve it. `overwrite` discards your local edit.

## Skills invariant (important)

- `~/.agents/skills/` holds real skill directories. `~/.claude/skills/`
  is symlinks pointing into it. Never write real files into
  `~/.claude/skills/` — it should contain only symlinks.
- The `skills` CLI (`/opt/homebrew/bin/skills`) treats `~/.agents/skills/`
  as state it owns and **prunes any directory not in `.skill-lock.json`**.
  Local-authored skills (yasqat-release, learn-quiz, etc.) are vulnerable.
- Canonical backups of local-only skills live in
  `dot_agents/local-only-skills/` (target: `~/.agents/local-only-skills/`).
  After any `skills` CLI operation, run
  `~/.agents/check-skill-symlinks.fish` to detect and restore prunes.

## Adding new tracked files

```fish
chezmoi add ~/.path/to/file          # add a file
chezmoi add --recursive ~/.some/dir  # add a dir
chezmoi forget ~/.path               # stop tracking (leaves target intact)
chezmoi -v apply                     # always preview-then-apply with -v
```

After `chezmoi add`, commit in the source repo:

```fish
chezmoi cd
git status; git add -p; git commit
```

## Secrets

`.gitignore` and chezmoi `private_` mode handle file perms, but neither
encrypts content. Do not put API keys / tokens in plain files. Use
`chezmoi secret` or templates with `1password` / `keychain` lookups if
you need to track secret-bearing configs.

## Keep the README in sync

`README.md` is the human reference (file tree, daily commands). Whenever
you change what this repo tracks or how the helpers work, update it in
the same commit:

- added/removed a tracked file → update the tree section
- new fish helper or new flag on an existing one → update the workflow
  section and any examples
- changed the bootstrap sequence (new CLI dep, new init step) → update
  the new-machine bootstrap block

If you're about to commit a change and haven't touched README.md, ask
yourself whether the change is visible to a future-you reading the
README. If yes, edit the README before committing.

## Don't

- Don't run `git` directly inside `~/` — only inside the chezmoi source
  dir (or use `chezmoi cd`).
- Don't `rm` files in `~/.claude/skills/` without checking they're orphan
  symlinks first (`check-skill-symlinks.fish`).
- Don't `cp` skills around manually — use the fish helpers in
  `~/.agents/` so backups and symlinks stay consistent.
- Don't add files to `.agents/skills/` and expect them to persist —
  the `skills` CLI will prune them. Put them in `.agents/local-only-skills/`
  and let `check-skill-symlinks.fish` restore them on demand.
