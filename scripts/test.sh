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

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
