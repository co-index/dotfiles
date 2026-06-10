#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_path="$claude_dir/settings.json"
hooks_dir="$claude_dir/hooks"
statusline_dir="$HOME/.config/ccstatusline"
bin_dir="$HOME/.local/bin"
state_path="$claude_dir/ccnotify-state.json"

backup_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
  fi
}

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

/usr/bin/python3 - "$settings_path" "$claude_dir" <<'PY'
import json
import os
import sys

settings_path = sys.argv[1]
claude_dir = sys.argv[2]

if os.path.exists(settings_path):
    with open(settings_path, "r", encoding="utf-8") as fh:
        try:
            settings = json.load(fh)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"Invalid JSON in {settings_path}: {exc}")
else:
    settings = {}

settings["statusLine"] = {
    "type": "command",
    "command": os.path.join(claude_dir, "ccstatusline-usage-api.sh"),
    "padding": 0,
}

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

with open(settings_path, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

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

echo "Installed Claude Code notifications and status line."
echo "Restart Claude Code to load the updated settings."
