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
check "bash -n claude/install.sh" bash -n "$repo_dir/claude/install.sh"
check "bash -n claude/scripts/notify-macos.sh" bash -n "$repo_dir/claude/scripts/notify-macos.sh"
check "bash -n claude/scripts/ccstatusline-usage-api.sh" bash -n "$repo_dir/claude/scripts/ccstatusline-usage-api.sh"
check "bash -n scripts/test.sh" bash -n "$repo_dir/scripts/test.sh"
check "json: claude-settings.example.json" /usr/bin/python3 -m json.tool "$repo_dir/claude/config/claude-settings.example.json"
check "json: ccstatusline-settings.json" /usr/bin/python3 -m json.tool "$repo_dir/claude/config/ccstatusline-settings.json"

echo "== Top-level installer =="
check "bash -n install.sh" bash -n "$repo_dir/install.sh"
check "no args prints usage and exits 0" bash "$repo_dir/install.sh"
usage_output="$(bash "$repo_dir/install.sh" 2>/dev/null || true)"
if grep -q "Usage:" <<<"$usage_output" && grep -q "claude" <<<"$usage_output"; then
  echo "ok: usage lists modules"
else
  echo "FAIL: usage lists modules"
  failures=$((failures + 1))
fi
expect_fail "unknown module fails" bash "$repo_dir/install.sh" no-such-module
expect_fail "--all rejects extra arguments" bash "$repo_dir/install.sh" --all claude

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

check "install.sh runs" env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/install.sh" claude
check "notify hook installed" test -x "$test_claude_dir/hooks/notify-macos.sh"
check "statusline wrapper installed" test -x "$test_claude_dir/ccstatusline-usage-api.sh"
check "ccstatusline settings installed" test -f "$tmp_home/.config/ccstatusline/settings.json"
check "settings.json is valid JSON" /usr/bin/python3 -m json.tool "$test_claude_dir/settings.json"

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

check "install.sh reruns" env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/install.sh" claude

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

echo "== ccnotify offline checks =="
check "bash -n claude/bin/ccnotify" bash -n "$repo_dir/claude/bin/ccnotify"
check "ccnotify help" env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/claude/bin/ccnotify" help
check "ccnotify with no args shows help" env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/claude/bin/ccnotify"
check "ccnotify version" env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/claude/bin/ccnotify" version

version_output="$(env CLAUDE_CONFIG_DIR="$tmp_home/empty-claude" bash "$repo_dir/claude/bin/ccnotify" version 2>/dev/null)"
if grep -q "installed version: unknown" <<<"$version_output"
then
  echo "ok: missing state reports unknown version"
else
  echo "FAIL: missing state reports unknown version"
  failures=$((failures + 1))
fi

expect_fail "check fails fast with placeholder repo" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/claude/bin/ccnotify" check
expect_fail "upgrade fails fast with placeholder repo" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/claude/bin/ccnotify" upgrade
expect_fail "install requires a version" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/claude/bin/ccnotify" install
expect_fail "rollback requires a version" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" CCNOTIFY_GITHUB_REPO="OWNER/REPO" bash "$repo_dir/claude/bin/ccnotify" rollback
expect_fail "unknown command fails" \
  env CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/claude/bin/ccnotify" frobnicate

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

installed_version_output="$(env CLAUDE_CONFIG_DIR="$test_claude_dir" "$tmp_home/.local/bin/ccnotify" version 2>/dev/null)"
if grep -q "installed version: dev" <<<"$installed_version_output"
then
  echo "ok: installed ccnotify reads recorded version"
else
  echo "FAIL: installed ccnotify reads recorded version"
  failures=$((failures + 1))
fi

check "release-style install runs" \
  env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" \
  CCNOTIFY_VERSION="v9.9.9" CCNOTIFY_REPO="example/repo" \
  bash "$repo_dir/claude/install.sh"

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

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
