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

jsonc_valid() {
  /usr/bin/python3 - "$1" <<'PY'
import json
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    text = fh.read()
text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
text = re.sub(r",\s*([}\]])", r"\1", text)
json.loads(text)
PY
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

echo "== Top-level uninstaller =="
check "bash -n uninstall.sh" bash -n "$repo_dir/uninstall.sh"
check "bash -n claude/uninstall.sh" bash -n "$repo_dir/claude/uninstall.sh"
check "bash -n vscode/uninstall.sh" bash -n "$repo_dir/vscode/uninstall.sh"
check "bash -n starship/uninstall.sh" bash -n "$repo_dir/starship/uninstall.sh"
check "uninstall: no args prints usage and exits 0" bash "$repo_dir/uninstall.sh"
expect_fail "uninstall: unknown module fails" bash "$repo_dir/uninstall.sh" no-such-module
expect_fail "uninstall: --all rejects extra arguments" bash "$repo_dir/uninstall.sh" --all claude

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
claude_hook_backups="$(find "$test_claude_dir/hooks" -maxdepth 1 -name 'notify-macos.sh.bak.*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$claude_hook_backups" -eq 0 ]]; then
  echo "ok: unchanged claude rerun skips hook backup"
else
  echo "FAIL: unchanged claude rerun skips hook backup"
  failures=$((failures + 1))
fi

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

echo "== claude uninstall =="
check "claude uninstall runs" \
  env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/uninstall.sh" claude
check "uninstall removed notify hook" test ! -e "$test_claude_dir/hooks/notify-macos.sh"
check "uninstall removed statusline wrapper" test ! -e "$test_claude_dir/ccstatusline-usage-api.sh"
check "uninstall removed ccstatusline settings" test ! -e "$tmp_home/.config/ccstatusline/settings.json"
check "uninstall removed ccnotify" test ! -e "$tmp_home/.local/bin/ccnotify"
check "uninstall removed state file" test ! -e "$test_claude_dir/ccnotify-state.json"
check "uninstall kept settings.json valid" /usr/bin/python3 -m json.tool "$test_claude_dir/settings.json"

if env CLAUDE_DIR="$test_claude_dir" /usr/bin/python3 - <<'PY' >/dev/null 2>&1
import json
import os

claude_dir = os.environ["CLAUDE_DIR"]
with open(os.path.join(claude_dir, "settings.json"), "r", encoding="utf-8") as fh:
    settings = json.load(fh)

assert settings.get("model") == "opus", "unrelated top-level key was lost"
assert "statusLine" not in settings, "statusLine was not removed"

hooks = settings.get("hooks", {})
assert "Stop" not in hooks, "project-only Stop event should be gone"

notification_commands = [
    hook["command"]
    for entry in hooks.get("Notification", [])
    for hook in entry.get("hooks", [])
]
assert "/usr/local/bin/custom-notification-hook.sh" in notification_commands, "custom hook was removed"
assert not any(
    c.endswith("/hooks/notify-macos.sh") for c in notification_commands
), "project hook still present"
PY
then
  echo "ok: uninstall keeps custom settings and strips project entries"
else
  echo "FAIL: uninstall keeps custom settings and strips project entries"
  failures=$((failures + 1))
fi

settings_backups_before="$(find "$test_claude_dir" -maxdepth 1 -name 'settings.json.bak.*' | wc -l | tr -d ' ')"
rerun_output="$(env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/uninstall.sh" claude 2>&1)" \
  && rerun_ok=1 || rerun_ok=0
if [[ "$rerun_ok" -eq 1 ]]; then
  echo "ok: claude uninstall reruns"
else
  echo "FAIL: claude uninstall reruns"
  failures=$((failures + 1))
fi
if grep -q "left unchanged" <<<"$rerun_output" && ! grep -q "Removed the project statusLine" <<<"$rerun_output"; then
  echo "ok: rerun reports settings left unchanged"
else
  echo "FAIL: rerun reports settings left unchanged"
  failures=$((failures + 1))
fi
settings_backups_after="$(find "$test_claude_dir" -maxdepth 1 -name 'settings.json.bak.*' | wc -l | tr -d ' ')"
if [[ "$settings_backups_after" -eq "$settings_backups_before" ]]; then
  echo "ok: rerun adds no settings backup"
else
  echo "FAIL: rerun adds no settings backup"
  failures=$((failures + 1))
fi

echo "== starship module =="
check "bash -n starship/install.sh" bash -n "$repo_dir/starship/install.sh"
check "bash -n starship/export.sh" bash -n "$repo_dir/starship/export.sh"
check "starship.toml exists and is non-empty" test -s "$repo_dir/starship/starship.toml"

starship_home="$tmp_home/starship-home"
mkdir -p "$starship_home"
check "starship install runs" env HOME="$starship_home" bash "$repo_dir/starship/install.sh"
check "starship.toml installed" test -f "$starship_home/.config/starship.toml"
check "starship install reruns" env HOME="$starship_home" bash "$repo_dir/starship/install.sh"
starship_backups="$(find "$starship_home/.config" -maxdepth 1 -name 'starship.toml.bak.*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$starship_backups" -eq 0 ]]; then
  echo "ok: unchanged starship rerun skips backup"
else
  echo "FAIL: unchanged starship rerun skips backup"
  failures=$((failures + 1))
fi
printf '\n# local tweak\n' >> "$starship_home/.config/starship.toml"
check "starship install over modified file" env HOME="$starship_home" bash "$repo_dir/starship/install.sh"
starship_backups="$(find "$starship_home/.config" -maxdepth 1 -name 'starship.toml.bak.*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$starship_backups" -ge 1 ]]; then
  echo "ok: modified starship file is backed up"
else
  echo "FAIL: modified starship file is backed up"
  failures=$((failures + 1))
fi

check "starship uninstall runs" env HOME="$starship_home" bash "$repo_dir/starship/uninstall.sh"
check "starship uninstall removed config" test ! -e "$starship_home/.config/starship.toml"
check "starship uninstall reruns" env HOME="$starship_home" bash "$repo_dir/starship/uninstall.sh"

starship_export_home="$tmp_home/starship-export-home"
mkdir -p "$starship_export_home/.config"
printf '# exported test config\n' > "$starship_export_home/.config/starship.toml"
starship_module_copy="$tmp_home/starship-module-copy"
mkdir -p "$starship_module_copy"
cp "$repo_dir/starship/export.sh" "$starship_module_copy/export.sh"
check "starship export runs" env HOME="$starship_export_home" bash "$starship_module_copy/export.sh"
check "starship export copied file" grep -q "exported test config" "$starship_module_copy/starship.toml"
expect_fail "starship export fails without source" \
  env HOME="$tmp_home/starship-missing-home" bash "$starship_module_copy/export.sh"

echo "== vscode module =="
check "bash -n vscode/install.sh" bash -n "$repo_dir/vscode/install.sh"
check "bash -n vscode/export.sh" bash -n "$repo_dir/vscode/export.sh"
check "vscode settings.json is valid JSON(C)" jsonc_valid "$repo_dir/vscode/settings.json"
check "vscode keybindings.json is valid JSON(C)" jsonc_valid "$repo_dir/vscode/keybindings.json"
check "vscode extensions.txt exists" test -f "$repo_dir/vscode/extensions.txt"

vscode_home="$tmp_home/vscode-home"
mkdir -p "$vscode_home"
vscode_user_dir="$vscode_home/Library/Application Support/Code/User"
vscode_install_output="$(env HOME="$vscode_home" PATH="/usr/bin:/bin" bash "$repo_dir/vscode/install.sh" 2>&1)" \
  && vscode_install_ok=1 || vscode_install_ok=0
if [[ "$vscode_install_ok" -eq 1 ]]; then
  echo "ok: vscode install runs without code CLI"
else
  echo "FAIL: vscode install runs without code CLI"
  failures=$((failures + 1))
fi
if grep -q "skipped installing extensions" <<<"$vscode_install_output"; then
  echo "ok: vscode install warns about missing code CLI"
else
  echo "FAIL: vscode install warns about missing code CLI"
  failures=$((failures + 1))
fi
check "vscode settings installed" test -f "$vscode_user_dir/settings.json"
check "vscode keybindings installed" test -f "$vscode_user_dir/keybindings.json"
check "vscode install reruns" env HOME="$vscode_home" PATH="/usr/bin:/bin" bash "$repo_dir/vscode/install.sh"
vscode_backups="$(find "$vscode_user_dir" -maxdepth 1 -name 'settings.json.bak.*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$vscode_backups" -eq 0 ]]; then
  echo "ok: unchanged vscode rerun skips backup"
else
  echo "FAIL: unchanged vscode rerun skips backup"
  failures=$((failures + 1))
fi
printf '\n// local tweak\n' >> "$vscode_user_dir/settings.json"
check "vscode install over modified file" env HOME="$vscode_home" PATH="/usr/bin:/bin" bash "$repo_dir/vscode/install.sh"
vscode_backups="$(find "$vscode_user_dir" -maxdepth 1 -name 'settings.json.bak.*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$vscode_backups" -ge 1 ]]; then
  echo "ok: modified vscode file is backed up"
else
  echo "FAIL: modified vscode file is backed up"
  failures=$((failures + 1))
fi

fake_code_dir="$tmp_home/fake-code-bin"
mkdir -p "$fake_code_dir"
cat > "$fake_code_dir/code" <<'SH'
#!/bin/bash
if [[ "$1" == "--install-extension" ]]; then
  echo "Error while installing extension $2: simulated marketplace failure" >&2
  exit 1
fi
exit 0
SH
chmod +x "$fake_code_dir/code"
vscode_fail_output="$(env HOME="$vscode_home" PATH="$fake_code_dir:/usr/bin:/bin" bash "$repo_dir/vscode/install.sh" 2>&1)" \
  && vscode_fail_ok=1 || vscode_fail_ok=0
if [[ "$vscode_fail_ok" -eq 1 ]] && grep -q "simulated marketplace failure" <<<"$vscode_fail_output"; then
  echo "ok: failed extension install surfaces the code CLI error"
else
  echo "FAIL: failed extension install surfaces the code CLI error"
  failures=$((failures + 1))
fi

check "vscode uninstall runs" env HOME="$vscode_home" PATH="/usr/bin:/bin" bash "$repo_dir/vscode/uninstall.sh"
check "vscode uninstall removed settings" test ! -e "$vscode_user_dir/settings.json"
check "vscode uninstall removed keybindings" test ! -e "$vscode_user_dir/keybindings.json"
check "vscode uninstall reruns" env HOME="$vscode_home" PATH="/usr/bin:/bin" bash "$repo_dir/vscode/uninstall.sh"

vscode_export_home="$tmp_home/vscode-export-home"
mkdir -p "$vscode_export_home/Library/Application Support/Code/User"
printf '{"export": "test"}\n' > "$vscode_export_home/Library/Application Support/Code/User/settings.json"
printf '[]\n' > "$vscode_export_home/Library/Application Support/Code/User/keybindings.json"
vscode_module_copy="$tmp_home/vscode-module-copy"
mkdir -p "$vscode_module_copy"
cp "$repo_dir/vscode/export.sh" "$vscode_module_copy/export.sh"
check "vscode export runs (no code CLI)" \
  env HOME="$vscode_export_home" PATH="/usr/bin:/bin" bash "$vscode_module_copy/export.sh"
check "vscode export copied settings" grep -q '"export": "test"' "$vscode_module_copy/settings.json"
check "vscode export copied keybindings" test -f "$vscode_module_copy/keybindings.json"
expect_fail "vscode export fails without source" \
  env HOME="$tmp_home/vscode-missing-home" PATH="/usr/bin:/bin" bash "$vscode_module_copy/export.sh"

echo "== install --all =="
all_home="$tmp_home/all-home"
mkdir -p "$all_home/.claude"
check "install --all runs" \
  env HOME="$all_home" CLAUDE_CONFIG_DIR="$all_home/.claude" PATH="/usr/bin:/bin" \
  bash "$repo_dir/install.sh" --all
check "all: claude hook installed" test -x "$all_home/.claude/hooks/notify-macos.sh"
check "all: ccnotify installed" test -x "$all_home/.local/bin/ccnotify"
check "all: vscode settings installed" test -f "$all_home/Library/Application Support/Code/User/settings.json"
check "all: starship config installed" test -f "$all_home/.config/starship.toml"

echo "== uninstall --all =="
check "uninstall --all runs" \
  env HOME="$all_home" CLAUDE_CONFIG_DIR="$all_home/.claude" PATH="/usr/bin:/bin" \
  bash "$repo_dir/uninstall.sh" --all
check "all: claude hook removed" test ! -e "$all_home/.claude/hooks/notify-macos.sh"
check "all: ccnotify removed" test ! -e "$all_home/.local/bin/ccnotify"
check "all: vscode settings removed" test ! -e "$all_home/Library/Application Support/Code/User/settings.json"
check "all: starship config removed" test ! -e "$all_home/.config/starship.toml"
check "all: settings.json still valid" /usr/bin/python3 -m json.tool "$all_home/.claude/settings.json"

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
