# Dotfiles Restructure Design

## Summary

Convert this repository from a single-purpose "Claude Code macOS notifications
and status line" project into an open-source, modular dotfiles repository named
`dotfiles`. The existing Claude Code setup becomes the `claude/` module;
new `vscode/` and `starship/` modules carry the user's VS Code and Starship
prompt configuration. A top-level installer selects which modules to install.

Decisions already made with the owner:

- Single repository holding all modules (no split).
- Repository name: `dotfiles`. It will be open-sourced.
- Sync mechanism: copy + timestamped backup on install, with per-module
  `export.sh` scripts to pull live machine config back into the repo.
- First batch of modules: `claude` (existing), `vscode` (settings,
  keybindings, extensions list), `starship` (starship.toml). zsh config is
  explicitly out of the first batch.
- Documentation must be detailed: every module's install instructions list
  prerequisites explicitly (the owner asked for this directly).

## Goals

- Restructure into per-module directories with `git mv` so history is kept.
- Keep the existing claude module fully working (installer, ccnotify, tests).
- Add `vscode/` and `starship/` modules with install + export scripts.
- Provide a top-level `install.sh` that installs selected modules or all.
- Keep the whole test suite offline and green after the move.
- Rewrite the README as a bilingual (中文/English) repository overview with
  detailed, prerequisite-first installation instructions per module.
- Seed `vscode/` and `starship/` with the owner's real local config, after a
  sensitive-content scan that the owner confirms.

## Non-Goals

- No zsh/iTerm/terminal-emulator modules in this iteration.
- No symlink-based sync (copy + backup only).
- No version manager beyond ccnotify, and ccnotify keeps managing only the
  claude module; other modules update via `git pull` + reinstall.
- No automatic export or auto-commit of machine config.
- No GitHub repository creation, remote setup, or release tagging in this
  iteration (the `OWNER/REPO` placeholder remains until the owner publishes).
- No Linux/Windows support claims; this stays macOS-first.

## Directory Structure

```text
dotfiles/                          # directory renamed from claude-code-macos-notify-statusline
├── README.md                      # rewritten: bilingual overview + module index
├── install.sh                     # NEW top-level entry: ./install.sh claude|vscode|starship|--all
├── scripts/
│   └── test.sh                    # top-level test entry: runs every module's offline checks
├── claude/                        # existing content moved here via git mv
│   ├── README.md                  # detailed claude docs (moved out of the root README)
│   ├── install.sh                 # existing installer, internal paths adjusted
│   ├── bin/ccnotify
│   ├── scripts/
│   │   ├── notify-macos.sh
│   │   └── ccstatusline-usage-api.sh
│   └── config/
│       ├── claude-settings.example.json
│       └── ccstatusline-settings.json
├── vscode/
│   ├── README.md                  # module docs: what it installs, prerequisites
│   ├── settings.json
│   ├── keybindings.json
│   ├── extensions.txt             # one extension id per line
│   ├── install.sh
│   └── export.sh
├── starship/
│   ├── README.md
│   ├── starship.toml
│   ├── install.sh
│   └── export.sh
└── docs/
    └── superpowers/               # specs and plans stay where they are
```

The old root-level `outputs/` placeholder directory is removed if still empty.

## Top-Level Installer

`./install.sh` with no arguments prints usage (module list, examples,
prerequisites pointer) and exits 0 — it never installs implicitly.

```bash
./install.sh claude            # one module
./install.sh vscode starship   # several modules
./install.sh --all             # everything
```

Behavior:

- Validates module names; unknown names fail with the usage text and exit 1.
- Runs each selected module's `<module>/install.sh` in sequence; stops at the
  first failure with a clear message naming the failed module.
- Top-level flags are minimal: `--all`, `-h/--help`. YAGNI applies.

## Module Contracts

Every module directory follows the same contract:

- `install.sh` — idempotent; backs up any file it would overwrite using the
  existing `.bak.YYYYMMDD-HHMMSS` convention; creates target directories;
  exits non-zero with a clear message when a prerequisite is missing.
- `export.sh` (vscode and starship only for now) — copies live machine config
  back into the module directory, prints a diff-style summary of what changed,
  reminds the user to review for sensitive content, and never runs git
  commands.
- `README.md` — module documentation (see Documentation Requirements).

### claude module

Existing behavior unchanged except path adjustments:

- All repo-relative paths inside `claude/install.sh` resolve against the
  module directory (the script already uses `BASH_SOURCE`-relative resolution;
  the contract stays "run from anywhere").
- `bin/ccnotify` adjustments: after downloading a release archive it currently
  verifies and runs the archive's top-level `install.sh`. It now verifies and
  runs `claude/install.sh` inside the archive. The state-file path-parsing
  fallback (`default_repo()` reading `bin/ccnotify`) updates to the new
  location `claude/bin/ccnotify`.
- ccnotify's scope is unchanged: it version-manages the claude module only.
  There are no published releases yet, so there is no compatibility burden.

### vscode module

Targets (macOS):

```text
~/Library/Application Support/Code/User/settings.json
~/Library/Application Support/Code/User/keybindings.json
```

- `install.sh`: backs up and copies both JSON files; then, if the `code` CLI
  is available, installs every extension in `extensions.txt` via
  `code --install-extension <id>` (continuing past individual failures and
  reporting a summary). If `code` is missing, it skips extensions with a
  warning that explains how to enable the CLI (VS Code → Command Palette →
  "Shell Command: Install 'code' command in PATH") and still exits 0 after
  the JSON copy.
- `export.sh`: copies the two JSON files from the live location into the
  module, regenerates `extensions.txt` via `code --list-extensions`, and
  prints a reminder to scan `settings.json` for secrets (tokens, proxies,
  private hosts) before committing.

### starship module

Target:

```text
~/.config/starship.toml
```

- `install.sh`: backs up and copies `starship.toml`. Warns (without failing)
  if the `starship` binary is not on `PATH`, pointing at
  `brew install starship` and the shell-init line
  `eval "$(starship init zsh)"`.
- `export.sh`: copies `~/.config/starship.toml` back into the module.

## Initial Content Seeding

As part of implementation, the owner's live config is imported:

- `vscode/settings.json` ← `~/Library/Application Support/Code/User/settings.json`
- `vscode/keybindings.json` ← `~/Library/Application Support/Code/User/keybindings.json`
- `vscode/extensions.txt` ← `code --list-extensions`
- `starship/starship.toml` ← `~/.config/starship.toml`

Before committing the seeded files, scan them for sensitive content (API
keys, tokens, internal hostnames, proxy credentials) and show the owner
anything suspicious for an explicit keep/strip decision. Nothing sensitive
ships in the open-source repo.

## Documentation Requirements

The owner explicitly asked for detailed installation instructions with
prerequisites spelled out. Concretely:

- The root `README.md` is bilingual (中文 first, English second, matching the
  current convention) and contains:
  - What the repository is and the module index with one-line descriptions.
  - A "Prerequisites / 前置条件" section listing shared requirements:
    macOS, git, `/usr/bin/python3` (ships with macOS developer tools), curl
    (ships with macOS).
  - A quick-start: clone, `./install.sh --all` or per-module, restart the
    affected apps.
  - A per-module summary table: what it installs, where, and its extra
    prerequisites, linking to each module README.
- Each module `README.md` (bilingual) contains, in order:
  1. What the module does (one paragraph).
  2. **Prerequisites** — explicit, complete, with install commands:
     - claude: Claude Code installed; Node.js + npm (the status line wrapper
       runs `npx -y ccstatusline@latest`); `/usr/bin/python3`; curl for
       ccnotify network commands.
     - vscode: VS Code installed; the `code` CLI on PATH for extension
       install/export (with the exact menu path to enable it); note that
       settings/keybindings copy works without the CLI.
     - starship: starship installed (`brew install starship`); the shell
       init line for zsh; a Nerd Font recommendation if the prompt config
       uses glyphs (verify against the actual seeded starship.toml).
  3. Files installed (exact paths).
  4. Install steps (top-level installer and direct module script).
  5. Export / update steps.
  6. Backup & restore behavior (`.bak.*` convention).
  7. Uninstall steps (exact `rm` commands and settings to revert).
  8. Troubleshooting (the existing claude troubleshooting moves here; each
     new module gets its likely failure modes: `code` not found, starship
     not initialized in shell, etc.).
- The existing detailed claude documentation moves from the root README into
  `claude/README.md`, staying bilingual. The root README keeps only the
  module summary and links.

## Testing

`scripts/test.sh` stays the single offline entry point and keeps the current
`check`/`expect_fail` helper style:

- Existing 30 checks move with the claude module; path references update
  (`claude/install.sh`, `claude/bin/ccnotify`, ...). The scratch-HOME install
  test calls the top-level installer (`./install.sh claude`) to also cover
  module dispatch.
- New top-level checks: usage output on no args (exit 0), unknown module
  fails (exit 1), `--all` in a scratch HOME installs every module's files.
- New vscode checks (offline, scratch HOME): `bash -n` both scripts; JSON
  validity of settings/keybindings; install copies both files and creates
  backups on rerun; extension install is skipped gracefully when `code` is
  absent from PATH (force via `PATH=/usr/bin:/bin`).
- New starship checks: `bash -n` both scripts; TOML file exists and is
  non-empty (no TOML parser dependency; do not over-validate); install copies
  the file into a scratch `~/.config`; rerun creates a backup.
- All tests remain network-free.

## Migration Plan (high level)

1. `git mv` existing claude files into `claude/`; adjust internal paths in
   `claude/install.sh`, `claude/bin/ccnotify`, and `scripts/test.sh`.
2. Add the top-level `install.sh` dispatcher.
3. Add `vscode/` and `starship/` modules (scripts first, TDD via
   `scripts/test.sh`).
4. Seed real config (with the sensitive-content review gate).
5. Rewrite root README; create module READMEs.
6. Rename the working directory `claude-code-macos-notify-statusline` →
   `dotfiles` as the final step (it invalidates open shells/editors, so it
   happens last; the git repo itself is directory-name-agnostic).

## Error Handling

- Top-level installer: unknown module → usage + exit 1; module script
  failure → stop, name the module, exit with its code.
- vscode install: missing `code` CLI is a warning, not an error; individual
  extension failures are collected and reported, not fatal.
- starship install: missing binary is a warning, not an error.
- Export scripts: missing source files fail with a clear message naming the
  expected path.

## Security / Sanitization

- The seeding step includes a manual review gate for `settings.json`,
  `keybindings.json`, and `starship.toml` before anything is committed.
- Export scripts always print the sensitive-content reminder.
- The existing "never commit real Claude state files" guidance stays in
  `claude/README.md`; `.gitignore` keeps covering `*.bak.*`.

## Open Items (deliberately out of scope)

- Creating the GitHub repository, pushing, and replacing the `OWNER/REPO`
  placeholder in `claude/bin/ccnotify` — happens at publish time.
- First release tag (`v1.0.0`) — publish time.
- Possible future modules (zsh, brew bundle, iTerm/Ghostty) — future specs.
