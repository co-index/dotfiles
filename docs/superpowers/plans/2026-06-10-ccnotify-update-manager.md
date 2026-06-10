# ccnotify Update Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `ccnotify` command that checks GitHub releases and explicitly installs, upgrades, or rolls back versions of this notification/status-line setup, plus a hooks-preserving installer and an offline test suite.

**Architecture:** Two installation surfaces stay separate: `install.sh` copies local repo files into place (now also installing `bin/ccnotify` to `~/.local/bin`, writing `ccnotify-state.json`, and merging hooks non-destructively), while `bin/ccnotify` resolves versions from GitHub Releases/tags, downloads a tagged archive, and runs that version's own `install.sh`. A new `scripts/test.sh` runs offline syntax, JSON, and temporary-HOME behavior checks.

**Tech Stack:** bash (`set -euo pipefail`), `/usr/bin/python3` heredocs for JSON work, `curl` + `tar` for downloads. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-10-ccnotify-update-manager-design.md`

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `scripts/test.sh` | Create | Offline test entry point: syntax checks, JSON validation, temp-HOME installer behavior, ccnotify offline behavior |
| `install.sh` | Modify | Existing local installer; gains hooks-preserving merge, ccnotify install, state file write, PATH warning |
| `bin/ccnotify` | Create | Version manager: help/version/check/upgrade/rollback/install against GitHub |
| `README.md` | Modify | Document ccnotify usage, new installed files, and test command (both 中文 and English sections) |

Conventions used throughout (match existing repo style):

- All scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- JSON is handled by `/usr/bin/python3` heredocs, never `jq`.
- Commit messages are short imperative sentences without `feat:`/`fix:` prefixes (matches `git log`).
- Test runs are `bash scripts/test.sh` from the repo root; expected final line on success is `All checks passed.`

---

### Task 0: Clean the working tree

The repo has an uncommitted bilingual rewrite of `README.md`. Commit it first so every later commit in this plan is single-purpose. **If executing in a fresh worktree, do this in the original checkout first (the worktree won't contain uncommitted changes).**

- [ ] **Step 1: Confirm the only pending change is README.md**

Run: `git status --short`
Expected: `M README.md` (plus possibly the untracked plan/spec docs directory)

- [ ] **Step 2: Commit it**

```bash
git add README.md
git commit -m "Restructure README into bilingual sections"
```

---

### Task 1: Baseline offline test harness

**Files:**
- Create: `scripts/test.sh`

- [ ] **Step 1: Write `scripts/test.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "ok: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

expect_fail() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL: $name (expected a non-zero exit)"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

echo "== Syntax and config checks =="
check "bash -n install.sh" bash -n "$repo_dir/install.sh"
check "bash -n scripts/notify-macos.sh" bash -n "$repo_dir/scripts/notify-macos.sh"
check "bash -n scripts/ccstatusline-usage-api.sh" bash -n "$repo_dir/scripts/ccstatusline-usage-api.sh"
check "bash -n scripts/test.sh" bash -n "$repo_dir/scripts/test.sh"
check "json: claude-settings.example.json" /usr/bin/python3 -m json.tool "$repo_dir/config/claude-settings.example.json"
check "json: ccstatusline-settings.json" /usr/bin/python3 -m json.tool "$repo_dir/config/ccstatusline-settings.json"

echo "== Installer behavior (temporary HOME) =="
tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT
test_claude_dir="$tmp_home/.claude"
mkdir -p "$test_claude_dir"

cat > "$test_claude_dir/settings.json" <<'JSON'
{
  "model": "opus",
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/custom-notification-hook.sh"
          }
        ]
      }
    ]
  }
}
JSON

check "install.sh runs" env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/install.sh"
check "notify hook installed" test -x "$test_claude_dir/hooks/notify-macos.sh"
check "statusline wrapper installed" test -x "$test_claude_dir/ccstatusline-usage-api.sh"
check "ccstatusline settings installed" test -f "$tmp_home/.config/ccstatusline/settings.json"
check "settings.json is valid JSON" /usr/bin/python3 -m json.tool "$test_claude_dir/settings.json"

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
```

- [ ] **Step 2: Make it executable and run it**

```bash
chmod +x scripts/test.sh
bash scripts/test.sh
```

Expected: every line starts with `ok:`, final line `All checks passed.`, exit code 0.

- [ ] **Step 3: Commit**

```bash
git add scripts/test.sh
git commit -m "Add offline test harness for installer and configs"
```

---

### Task 2: Hooks-preserving settings merge

The current installer replaces the whole `Notification`/`Stop` arrays, destroying user hooks. Add failing tests first, then fix `install.sh`.

**Files:**
- Modify: `scripts/test.sh` (add assertions after the `"settings.json is valid JSON"` check)
- Modify: `install.sh` (the python heredoc, currently lines 52–56)

- [ ] **Step 1: Add failing tests to `scripts/test.sh`**

Insert this block immediately after the `check "settings.json is valid JSON" ...` line and before the final `echo` / failure-count block:

```bash
if env CLAUDE_DIR="$test_claude_dir" /usr/bin/python3 - <<'PY' >/dev/null 2>&1
import json
import os

claude_dir = os.environ["CLAUDE_DIR"]
with open(os.path.join(claude_dir, "settings.json"), "r", encoding="utf-8") as fh:
    settings = json.load(fh)

assert settings.get("model") == "opus", "unrelated top-level key was lost"

notification_commands = [
    hook["command"]
    for entry in settings["hooks"]["Notification"]
    for hook in entry.get("hooks", [])
]
assert "/usr/local/bin/custom-notification-hook.sh" in notification_commands, "custom hook was removed"
assert any(c.endswith("/hooks/notify-macos.sh") for c in notification_commands), "project Notification hook missing"

stop_commands = [
    hook["command"]
    for entry in settings["hooks"]["Stop"]
    for hook in entry.get("hooks", [])
]
assert any(c.endswith("/hooks/notify-macos.sh") for c in stop_commands), "project Stop hook missing"
PY
then
  echo "ok: unrelated settings and hooks preserved"
else
  echo "FAIL: unrelated settings and hooks preserved"
  failures=$((failures + 1))
fi

check "install.sh reruns" env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/install.sh"

if env CLAUDE_DIR="$test_claude_dir" /usr/bin/python3 - <<'PY' >/dev/null 2>&1
import json
import os

claude_dir = os.environ["CLAUDE_DIR"]
with open(os.path.join(claude_dir, "settings.json"), "r", encoding="utf-8") as fh:
    settings = json.load(fh)

for event in ("Notification", "Stop"):
    commands = [
        hook["command"]
        for entry in settings["hooks"][event]
        for hook in entry.get("hooks", [])
    ]
    ours = [c for c in commands if c.endswith("/hooks/notify-macos.sh")]
    assert len(ours) == 1, f"{event}: expected exactly one project hook, found {len(ours)}"
PY
then
  echo "ok: rerun does not duplicate hooks"
else
  echo "FAIL: rerun does not duplicate hooks"
  failures=$((failures + 1))
fi
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/test.sh`
Expected: `FAIL: unrelated settings and hooks preserved` (the current installer wipes the custom hook), exit code 1.

- [ ] **Step 3: Fix the merge in `install.sh`**

In the python heredoc inside `install.sh`, replace this block:

```python
notify_command = os.path.join(claude_dir, "hooks", "notify-macos.sh")
hook_entry = {"hooks": [{"type": "command", "command": notify_command}]}
hooks = settings.setdefault("hooks", {})
for event in ("Notification", "Stop"):
    hooks[event] = [hook_entry]
```

with:

```python
notify_command = os.path.join(claude_dir, "hooks", "notify-macos.sh")
hooks = settings.get("hooks")
if not isinstance(hooks, dict):
    hooks = settings["hooks"] = {}
for event in ("Notification", "Stop"):
    entries = hooks.get(event)
    if not isinstance(entries, list):
        entries = hooks[event] = []
    found = False
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        entry_hooks = entry.get("hooks")
        if not isinstance(entry_hooks, list):
            continue
        for hook in entry_hooks:
            if (
                isinstance(hook, dict)
                and isinstance(hook.get("command"), str)
                and hook["command"].endswith("/hooks/notify-macos.sh")
            ):
                hook["type"] = "command"
                hook["command"] = notify_command
                found = True
    if not found:
        entries.append({"hooks": [{"type": "command", "command": notify_command}]})
```

The match key is `command` ending in `/hooks/notify-macos.sh` — that identifies this project's hook regardless of the configured Claude directory, while leaving every other entry untouched. Re-running updates the existing entry in place, so reruns never duplicate.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/test.sh`
Expected: all `ok:`, `All checks passed.`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add install.sh scripts/test.sh
git commit -m "Preserve existing user hooks when merging settings"
```

---

### Task 3: The `bin/ccnotify` command

**Files:**
- Create: `bin/ccnotify`
- Modify: `scripts/test.sh` (new offline test section)

Design notes baked into the code below:

- `GITHUB_REPO` is the single configuration point (spec requirement). The `CCNOTIFY_GITHUB_REPO` env override exists so tests can force the placeholder path forever, even after the real repo name ships.
- Network commands fail fast while the placeholder is unchanged.
- Version comparison is equality-only — `check` reports "different version available" rather than claiming semver ordering (spec: don't claim comparisons you can't prove).
- `upgrade`/`rollback`/`install` download `https://github.com/<repo>/archive/refs/tags/<version>.tar.gz`, verify `install.sh` exists in the extracted tree, and run that version's installer with `CCNOTIFY_VERSION`, `CCNOTIFY_PREVIOUS_VERSION`, and `CCNOTIFY_REPO` exported so the installer can write state (wired up in Task 4).

- [ ] **Step 1: Add failing tests to `scripts/test.sh`**

Insert this block after the `"rerun does not duplicate hooks"` block and before the final `echo` / failure-count block:

```bash
echo "== ccnotify offline checks =="
check "bash -n bin/ccnotify" bash -n "$repo_dir/bin/ccnotify"
check "ccnotify help" env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/bin/ccnotify" help
check "ccnotify with no args shows help" env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/bin/ccnotify"
check "ccnotify version" env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/bin/ccnotify" version

if env CLAUDE_CONFIG_DIR="$tmp_home/empty-claude" bash "$repo_dir/bin/ccnotify" version 2>/dev/null \
  | grep -q "installed version: unknown"
then
  echo "ok: missing state reports unknown version"
else
  echo "FAIL: missing state reports unknown version"
  failures=$((failures + 1))
fi

expect_fail "check fails fast with placeholder repo" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/bin/ccnotify" check
expect_fail "upgrade fails fast with placeholder repo" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/bin/ccnotify" upgrade
expect_fail "install requires a version" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/bin/ccnotify" install
expect_fail "rollback requires a version" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/bin/ccnotify" rollback
expect_fail "unknown command fails" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/bin/ccnotify" frobnicate
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/test.sh`
Expected: every line in the `ccnotify offline checks` section is `FAIL:` (the file does not exist; note `expect_fail` lines report `ok:` misleadingly only if the command fails — a missing file also exits non-zero, so those show `ok:`. The `check` lines fail.), exit code 1.

- [ ] **Step 3: Write `bin/ccnotify`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# The one configuration point for the release source (see design doc).
# Replace OWNER/REPO with the real GitHub repository before publishing.
# CCNOTIFY_GITHUB_REPO overrides it, which the test suite uses to force
# placeholder behavior without touching the network.
GITHUB_REPO="${CCNOTIFY_GITHUB_REPO:-OWNER/REPO}"
PLACEHOLDER_REPO="OWNER/REPO"

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
state_file="$claude_dir/ccnotify-state.json"

usage() {
  cat <<EOF
ccnotify - version manager for Claude Code macOS notifications and status line

Usage:
  ccnotify help                 Show this help. No network access.
  ccnotify version              Show the locally recorded version and paths.
  ccnotify check                Check GitHub for the latest version. Never installs.
  ccnotify upgrade              Install the latest available version.
  ccnotify upgrade <version>    Install the specified version.
  ccnotify rollback <version>   Install the specified older version.
  ccnotify install <version>    Install the specified version.

Examples:
  ccnotify check
  ccnotify upgrade
  ccnotify upgrade v1.2.0
  ccnotify rollback v1.1.0

Paths:
  github repo:       $GITHUB_REPO
  state file:        $state_file
  claude config dir: $claude_dir
EOF
}

die() {
  echo "ccnotify: $*" >&2
  exit 1
}

require_repo() {
  if [[ "$GITHUB_REPO" == "$PLACEHOLDER_REPO" ]]; then
    die "GITHUB_REPO is still the $PLACEHOLDER_REPO placeholder; edit bin/ccnotify (or set CCNOTIFY_GITHUB_REPO) before using network commands"
  fi
}

require_curl() {
  command -v curl >/dev/null 2>&1 || die "curl is required for this command"
}

state_value() {
  /usr/bin/python3 - "$state_file" "$1" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as fh:
        state = json.load(fh)
except Exception:
    print("unknown", end="")
else:
    value = state.get(key)
    if isinstance(value, str) and value:
        print(value, end="")
    else:
        print("unknown", end="")
PY
}

latest_version() {
  local tag
  tag="$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null \
    | /usr/bin/python3 -c 'import json, sys
try:
    print(json.load(sys.stdin).get("tag_name") or "", end="")
except Exception:
    pass' || true)"
  if [[ -z "$tag" ]]; then
    tag="$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/tags?per_page=1" 2>/dev/null \
      | /usr/bin/python3 -c 'import json, sys
try:
    tags = json.load(sys.stdin)
    print((tags[0].get("name") or "") if tags else "", end="")
except Exception:
    pass' || true)"
  fi
  [[ -n "$tag" ]] || die "could not determine the latest version for $GITHUB_REPO (no releases or tags reachable)"
  printf '%s' "$tag"
}

cmd_version() {
  echo "ccnotify - Claude Code macOS notifications and status line"
  echo "installed version: $(state_value version)"
  echo "github repo:       $GITHUB_REPO"
  echo "state file:        $state_file"
  echo "claude config dir: $claude_dir"
}

cmd_check() {
  require_repo
  require_curl
  local installed latest
  installed="$(state_value version)"
  latest="$(latest_version)"
  echo "installed: $installed"
  echo "latest:    $latest"
  if [[ "$installed" == "$latest" ]]; then
    echo "You are up to date."
  else
    echo "A different version is available."
    echo "Run 'ccnotify upgrade' or 'ccnotify install $latest' to install it."
  fi
}

install_version() {
  local version="$1"
  local label="$2"
  require_repo
  require_curl

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  local archive="$tmp_dir/ccnotify-src.tar.gz"
  echo "Downloading $GITHUB_REPO at $version ..."
  if ! curl -fsSL -o "$archive" "https://github.com/$GITHUB_REPO/archive/refs/tags/$version.tar.gz"; then
    die "failed to download version $version (does the tag exist?)"
  fi

  if ! tar -xzf "$archive" -C "$tmp_dir"; then
    die "failed to extract the downloaded archive"
  fi

  local src_dir
  src_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "$src_dir" || ! -f "$src_dir/install.sh" ]]; then
    die "version $version does not contain install.sh; cannot install it"
  fi

  local previous
  previous="$(state_value version)"

  echo "Running the $version installer ..."
  if ! CCNOTIFY_VERSION="$version" \
       CCNOTIFY_PREVIOUS_VERSION="$previous" \
       CCNOTIFY_REPO="$GITHUB_REPO" \
       bash "$src_dir/install.sh"; then
    die "the $version installer failed; your previous files remain in their .bak.* backups"
  fi

  echo "ccnotify: $label to $version complete."
}

main() {
  local cmd="${1:-help}"
  case "$cmd" in
    help|-h|--help)
      usage
      ;;
    version)
      cmd_version
      ;;
    check)
      cmd_check
      ;;
    upgrade)
      require_repo
      require_curl
      if [[ $# -ge 2 ]]; then
        install_version "$2" "upgrade"
      else
        local target
        target="$(latest_version)"
        install_version "$target" "upgrade"
      fi
      ;;
    rollback)
      [[ $# -ge 2 ]] || die "rollback requires a version, for example: ccnotify rollback v1.1.0"
      install_version "$2" "rollback"
      ;;
    install)
      [[ $# -ge 2 ]] || die "install requires a version, for example: ccnotify install v1.2.0"
      install_version "$2" "install"
      ;;
    *)
      die "unknown command: $cmd (run 'ccnotify help')"
      ;;
  esac
}

main "$@"
```

- [ ] **Step 4: Make it executable and run the tests**

```bash
chmod +x bin/ccnotify
bash scripts/test.sh
```

Expected: all `ok:`, `All checks passed.`, exit 0. No network access happens: the placeholder guard fires before any `curl`.

- [ ] **Step 5: Commit**

```bash
git add bin/ccnotify scripts/test.sh
git commit -m "Add ccnotify release version manager command"
```

---

### Task 4: Installer integration — install ccnotify, write state, warn about PATH

**Files:**
- Modify: `install.sh`
- Modify: `scripts/test.sh` (new "installed ccnotify and state" section)

- [ ] **Step 1: Add failing tests to `scripts/test.sh`**

Insert after the `ccnotify offline checks` section (after the `"unknown command fails"` line), before the final `echo` / failure-count block:

```bash
echo "== Installed ccnotify and state file =="
check "ccnotify installed to ~/.local/bin" test -x "$tmp_home/.local/bin/ccnotify"
check "state file is valid JSON" /usr/bin/python3 -m json.tool "$test_claude_dir/ccnotify-state.json"

if env STATE="$test_claude_dir/ccnotify-state.json" /usr/bin/python3 - <<'PY' >/dev/null 2>&1
import json
import os

with open(os.environ["STATE"], "r", encoding="utf-8") as fh:
    state = json.load(fh)

assert state.get("version") == "dev", f"local install should record version dev, got {state.get('version')}"
assert state.get("source") == "local", f"local install should record source local, got {state.get('source')}"
assert state.get("repo"), "repo missing from state"
assert state.get("installedAt"), "installedAt missing from state"
PY
then
  echo "ok: local install writes dev state"
else
  echo "FAIL: local install writes dev state"
  failures=$((failures + 1))
fi

if env CLAUDE_CONFIG_DIR="$test_claude_dir" "$tmp_home/.local/bin/ccnotify" version 2>/dev/null \
  | grep -q "installed version: dev"
then
  echo "ok: installed ccnotify reads recorded version"
else
  echo "FAIL: installed ccnotify reads recorded version"
  failures=$((failures + 1))
fi

check "release-style install runs" \
  env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" \
  CCNOTIFY_VERSION="v9.9.9" CCNOTIFY_REPO="example/repo" \
  bash "$repo_dir/install.sh"

if env STATE="$test_claude_dir/ccnotify-state.json" /usr/bin/python3 - <<'PY' >/dev/null 2>&1
import json
import os

with open(os.environ["STATE"], "r", encoding="utf-8") as fh:
    state = json.load(fh)

assert state.get("version") == "v9.9.9", f"expected v9.9.9, got {state.get('version')}"
assert state.get("source") == "release", f"expected source release, got {state.get('source')}"
assert state.get("repo") == "example/repo", f"expected repo example/repo, got {state.get('repo')}"
assert state.get("previousVersion") == "dev", f"expected previousVersion dev, got {state.get('previousVersion')}"
PY
then
  echo "ok: release install records version, repo, and previous version"
else
  echo "FAIL: release install records version, repo, and previous version"
  failures=$((failures + 1))
fi
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/test.sh`
Expected: the four new checks in `Installed ccnotify and state file` report `FAIL:` (`~/.local/bin/ccnotify` and the state file don't exist yet), exit 1.

- [ ] **Step 3: Extend `install.sh`**

Three edits.

**(a)** After the existing variable block at the top (`statusline_dir="$HOME/.config/ccstatusline"`), add:

```bash
bin_dir="$HOME/.local/bin"
state_path="$claude_dir/ccnotify-state.json"
```

**(b)** Replace the existing `mkdir`/backup/copy section:

```bash
mkdir -p "$hooks_dir" "$statusline_dir"

backup_file "$hooks_dir/notify-macos.sh"
backup_file "$claude_dir/ccstatusline-usage-api.sh"
backup_file "$statusline_dir/settings.json"
backup_file "$settings_path"

cp "$repo_dir/scripts/notify-macos.sh" "$hooks_dir/notify-macos.sh"
cp "$repo_dir/scripts/ccstatusline-usage-api.sh" "$claude_dir/ccstatusline-usage-api.sh"
cp "$repo_dir/config/ccstatusline-settings.json" "$statusline_dir/settings.json"
chmod +x "$hooks_dir/notify-macos.sh" "$claude_dir/ccstatusline-usage-api.sh"
```

with:

```bash
mkdir -p "$hooks_dir" "$statusline_dir" "$bin_dir"

backup_file "$hooks_dir/notify-macos.sh"
backup_file "$claude_dir/ccstatusline-usage-api.sh"
backup_file "$statusline_dir/settings.json"
backup_file "$settings_path"
backup_file "$bin_dir/ccnotify"

cp "$repo_dir/scripts/notify-macos.sh" "$hooks_dir/notify-macos.sh"
cp "$repo_dir/scripts/ccstatusline-usage-api.sh" "$claude_dir/ccstatusline-usage-api.sh"
cp "$repo_dir/config/ccstatusline-settings.json" "$statusline_dir/settings.json"
cp "$repo_dir/bin/ccnotify" "$bin_dir/ccnotify"
chmod +x "$hooks_dir/notify-macos.sh" "$claude_dir/ccstatusline-usage-api.sh" "$bin_dir/ccnotify"
```

The state file gets no `.bak` — it is regenerated metadata, and `previousVersion` already records history.

**(c)** After the existing settings-merge python heredoc (after its closing `PY`), and before the final two `echo` lines, add:

```bash
/usr/bin/python3 - "$state_path" "$repo_dir/bin/ccnotify" <<'PY'
import datetime
import json
import os
import sys

state_path = sys.argv[1]
ccnotify_path = sys.argv[2]

def default_repo():
    # bin/ccnotify is the single configuration point for the repo name;
    # read its GITHUB_REPO default instead of duplicating it here.
    try:
        with open(ccnotify_path, "r", encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("GITHUB_REPO="):
                    return line.split(":-", 1)[1].split("}", 1)[0]
    except Exception:
        pass
    return "OWNER/REPO"

old = {}
if os.path.exists(state_path):
    try:
        with open(state_path, "r", encoding="utf-8") as fh:
            old = json.load(fh)
    except Exception:
        old = {}

version = os.environ.get("CCNOTIFY_VERSION") or ""
state = {
    "version": version or "dev",
    "repo": os.environ.get("CCNOTIFY_REPO") or old.get("repo") or default_repo(),
    "installedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source": "release" if version else "local",
    "previousVersion": os.environ.get("CCNOTIFY_PREVIOUS_VERSION") or old.get("version"),
}

with open(state_path, "w", encoding="utf-8") as fh:
    json.dump(state, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    echo "Note: $bin_dir is not on your PATH."
    echo "Add this line to your shell profile to use the ccnotify command:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac
```

The PATH warning prints a snippet but never edits shell startup files (spec requirement).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/test.sh`
Expected: all `ok:`, `All checks passed.`, exit 0.

One quirk to know: the `release-style install runs` test reruns the installer with `CCNOTIFY_VERSION` set, so the earlier `dev` state assertions must run **before** it — the insertion order in Step 1 already guarantees this. Don't reorder.

- [ ] **Step 5: Commit**

```bash
git add install.sh scripts/test.sh
git commit -m "Install ccnotify command and record install state"
```

---

### Task 5: Document ccnotify in the README

**Files:**
- Modify: `README.md` (both the 中文 and English sections)

- [ ] **Step 1: Update the 中文 section**

**(a)** In `### 安装内容`, replace the file list:

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
```

with:

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
~/.local/bin/ccnotify
~/.claude/ccnotify-state.json
```

**(b)** Insert a new section between `### 配置说明` 的结尾（`...会提示当前任务已结束。` 一行之后）and `### 自定义`:

````markdown
### 更新与回滚

安装脚本会把 `ccnotify` 命令安装到 `~/.local/bin/ccnotify`，用于按 GitHub
Release 版本管理本套配置。所有安装操作都需要显式执行，`check` 只查询、
永远不会自动安装：

```bash
ccnotify check            # 检查最新版本，只查询不安装
ccnotify upgrade          # 升级到最新版本
ccnotify upgrade v1.2.0   # 安装指定版本
ccnotify rollback v1.1.0  # 回滚到指定旧版本
ccnotify version          # 查看当前安装的版本和路径
```

升级和回滚都会下载对应版本的源码包，并运行那个版本自带的 `install.sh`，
所以同样会先备份再覆盖。

如果 `~/.local/bin` 不在 `PATH` 中，安装脚本会提示你在 shell 配置里加入：

```bash
export PATH="$HOME/.local/bin:$PATH"
```
````

**(c)** In `### 测试`, add before the 通知脚本 test:

````markdown
运行离线测试套件（语法检查、配置校验和临时目录安装测试）：

```bash
bash scripts/test.sh
```
````

**(d)** In `### 恢复或卸载`, replace the `rm` block:

```bash
rm -f ~/.claude/hooks/notify-macos.sh
rm -f ~/.claude/ccstatusline-usage-api.sh
rm -f ~/.config/ccstatusline/settings.json
```

with:

```bash
rm -f ~/.claude/hooks/notify-macos.sh
rm -f ~/.claude/ccstatusline-usage-api.sh
rm -f ~/.config/ccstatusline/settings.json
rm -f ~/.local/bin/ccnotify
rm -f ~/.claude/ccnotify-state.json
```

- [ ] **Step 2: Update the English section (mirror of Step 1)**

**(a)** In `### Installed Files`, make the same two-line addition to the file list.

**(b)** Insert between the end of `### Configuration` (after the line `finished.`) and `### Customization`:

````markdown
### Update and Rollback

The installer also installs a `ccnotify` command to `~/.local/bin/ccnotify`
that manages this setup by GitHub release version. Every install is explicit;
`check` only reports and never installs anything:

```bash
ccnotify check            # check the latest version, report only
ccnotify upgrade          # install the latest version
ccnotify upgrade v1.2.0   # install a specific version
ccnotify rollback v1.1.0  # roll back to an older version
ccnotify version          # show the installed version and paths
```

Upgrades and rollbacks download the source archive for the requested version
and run that version's own `install.sh`, so the usual backups still apply.

If `~/.local/bin` is not on your `PATH`, the installer prints a snippet to add
to your shell profile:

```bash
export PATH="$HOME/.local/bin:$PATH"
```
````

**(c)** In `### Testing`, add before the notification hook test:

````markdown
Run the offline test suite (syntax checks, config validation, and a
temporary-directory install test):

```bash
bash scripts/test.sh
```
````

**(d)** In `### Restore or Uninstall`, make the same two-line addition to the `rm` block as the 中文 section.

- [ ] **Step 3: Sanity-check and commit**

```bash
bash scripts/test.sh
git add README.md
git commit -m "Document ccnotify update and rollback commands"
```

Expected: tests still pass (README changes can't break them, but run anyway as the pre-commit habit).

---

### Task 6: Final verification

- [ ] **Step 1: Full test run**

Run: `bash scripts/test.sh`
Expected: every check `ok:`, final line `All checks passed.`, exit 0.

- [ ] **Step 2: Manual smoke checks**

```bash
bash bin/ccnotify help
bash bin/ccnotify version
bash bin/ccnotify check || true
```

Expected: `help` prints usage with the paths block; `version` prints `installed version:` (either `unknown` or your real local state — this reads the real `~/.claude/ccnotify-state.json`, which is fine and read-only); `check` fails with the placeholder-repo configuration message.

- [ ] **Step 3: Confirm clean history**

Run: `git log --oneline -8` and `git status --short`
Expected: one commit per task, clean tree.

---

## Out of Scope (deliberate)

- Replacing the `OWNER/REPO` placeholder — happens when the GitHub repository is created and the first release is tagged (release checklist item, not code).
- Network-dependent tests against the real GitHub API — spec makes these opt-in; none are included.
- Uninstall command, background updater, shell-profile editing — all spec non-goals.
