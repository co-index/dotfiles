# ccnotify Update Manager Design

## Summary

Add a user-level `ccnotify` command that can check for new GitHub release
versions, install a requested version, upgrade to the latest version, and roll
back by installing a specified older version.

The update mechanism must never install automatically. Users explicitly run an
installing command when they want to change their local setup.

## Goals

- Install a `ccnotify` command to `~/.local/bin/ccnotify`.
- Support release-based version checks from GitHub.
- Support explicit upgrades to latest or to a specified version.
- Support rollback by installing a specified older version.
- Keep the existing backup behavior before overwriting installed files.
- Record enough local state to show the current installed version.
- Keep the implementation dependency-light for macOS users.

## Non-Goals

- No background updater.
- No silent or automatic installation after `check`.
- No sudo or system-wide install path.
- No full filesystem snapshot rollback.
- No default network-dependent test suite.

## Architecture

The repository will have two installation surfaces:

- `install.sh` remains the local installer. It copies repository files into the
  Claude Code configuration directories, writes Claude Code settings, installs
  the `ccnotify` command, and writes local state.
- `bin/ccnotify` is the version manager. It talks to GitHub Releases/tags,
  downloads a requested version, extracts it into a temporary directory, checks
  for `install.sh`, and runs that version's installer.

This keeps local installation separate from network version management. The
installer is reusable whether the repository was cloned manually or downloaded
by `ccnotify`.

## Commands

`ccnotify` with no arguments is equivalent to `ccnotify help`.

```bash
ccnotify help
ccnotify version
ccnotify check
ccnotify upgrade
ccnotify upgrade v1.2.0
ccnotify rollback v1.1.0
ccnotify install v1.2.0
```

Command behavior:

- `help`: prints usage, examples, configuration paths, and exits without
  network access.
- `version`: prints the locally recorded version, repo, state file path, and
  Claude config directory.
- `check`: fetches the latest available release/tag and reports whether it
  differs from the local version. It never installs.
- `upgrade`: installs the latest available release/tag.
- `upgrade <version>`: installs the specified version.
- `rollback <version>`: installs the specified version and labels the operation
  as a rollback in output.
- `install <version>`: lower-level explicit install command for a specific
  version.

Version comparison should prefer simple semantic tags like `v1.2.3`. If a tag
does not match that shape, the command should still display it, but avoid
claiming ordered semver comparisons it cannot prove.

## Release Source

`bin/ccnotify` will keep the GitHub repository name in one top-level variable,
for example:

```bash
GITHUB_REPO="owner/repo"
```

If the value is still the placeholder, network commands must fail with a clear
configuration message instead of making a bad request.

Latest-version discovery should prefer the GitHub latest release endpoint. If
the repository does not publish releases, the command may fall back to the tags
API and use the first returned tag.

## Installed Files

The installer writes:

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
~/.local/bin/ccnotify
~/.claude/ccnotify-state.json
```

`CLAUDE_CONFIG_DIR` continues to override the Claude Code configuration
directory. `ccnotify` remains installed under `$HOME/.local/bin`.

If `~/.local/bin` is not on `PATH`, the installer should print a warning with a
shell snippet the user can add manually. It must not edit shell startup files.

## State File

The state file is stored under the Claude Code configuration directory:

```text
~/.claude/ccnotify-state.json
```

Suggested shape:

```json
{
  "version": "v1.2.0",
  "repo": "owner/repo",
  "installedAt": "2026-06-10T12:00:00Z",
  "source": "release",
  "previousVersion": "v1.1.0"
}
```

The state file is for display and comparison, not as the only source of truth.
If it is missing or invalid, `ccnotify version` should show `unknown`, and
`ccnotify install <version>` should still work.

## Install And Update Flow

Initial local install:

1. User runs `./install.sh` from a clone or extracted archive.
2. `install.sh` backs up existing target files with `.bak.TIMESTAMP` suffixes.
3. `install.sh` copies scripts, status line config, and `bin/ccnotify`.
4. `install.sh` updates Claude Code settings.
5. `install.sh` writes `ccnotify-state.json`.
6. `install.sh` warns if `~/.local/bin` is not on `PATH`.

Upgrade or rollback:

1. User runs `ccnotify upgrade`, `ccnotify upgrade <version>`, or
   `ccnotify rollback <version>`.
2. `ccnotify` resolves the target version from GitHub.
3. `ccnotify` downloads the target source archive to a temporary directory.
4. `ccnotify` extracts the archive and verifies that `install.sh` exists.
5. `ccnotify` executes that version's `install.sh`.
6. The target installer performs backup, copy, settings merge, and state write.

## Settings Merge Behavior

The current installer replaces the `Notification` and `Stop` hook arrays. The
update-manager work should also change this behavior so the installer preserves
other user hooks.

Desired behavior:

- Preserve unrelated `settings.json` keys.
- Preserve other hook entries for `Notification` and `Stop`.
- Add this project's hook if missing.
- Update this project's hook command path if it already exists.

This lowers the risk of upgrading or rolling back on a machine with custom
Claude Code hooks.

## Error Handling

The command should stop with a clear message when:

- GitHub repository configuration still uses a placeholder.
- `curl` is missing.
- GitHub latest release/tag lookup fails.
- The requested version does not exist.
- The archive download fails.
- The archive cannot be extracted.
- The extracted version does not contain `install.sh`.
- The version installer exits non-zero.

Failed update attempts should not claim success or write a new successful state
record. Backups made by `install.sh` remain available for manual restoration.

## Testing

Add a lightweight test entry point such as `scripts/test.sh`.

Default offline checks:

```bash
bash -n install.sh
bash -n scripts/notify-macos.sh
bash -n scripts/ccstatusline-usage-api.sh
bash -n bin/ccnotify
python3 -m json.tool config/claude-settings.example.json
python3 -m json.tool config/ccstatusline-settings.json
```

Temporary-directory behavior tests:

- Running `install.sh` with temporary `HOME` and `CLAUDE_CONFIG_DIR` installs all
  expected files, including `~/.local/bin/ccnotify` and
  `ccnotify-state.json`.
- Existing `settings.json` with unrelated hooks keeps those hooks after install,
  while this project's hook is added or updated.

Network checks for GitHub should be opt-in rather than part of the default test
suite.

## Open Implementation Notes

- The first implementation can use shell plus `/usr/bin/python3` for JSON
  parsing, matching the existing project style.
- The public repository URL must be replaced before release. Until then, network
  commands should fail fast with a helpful message.
- Rollback means installing a specified older release, not restoring a complete
  timestamped machine state.
