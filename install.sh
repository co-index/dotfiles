#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_path="$claude_dir/settings.json"
hooks_dir="$claude_dir/hooks"
statusline_dir="$HOME/.config/ccstatusline"

backup_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
  fi
}

mkdir -p "$hooks_dir" "$statusline_dir"

backup_file "$hooks_dir/notify-macos.sh"
backup_file "$claude_dir/ccstatusline-usage-api.sh"
backup_file "$statusline_dir/settings.json"
backup_file "$settings_path"

cp "$repo_dir/scripts/notify-macos.sh" "$hooks_dir/notify-macos.sh"
cp "$repo_dir/scripts/ccstatusline-usage-api.sh" "$claude_dir/ccstatusline-usage-api.sh"
cp "$repo_dir/config/ccstatusline-settings.json" "$statusline_dir/settings.json"
chmod +x "$hooks_dir/notify-macos.sh" "$claude_dir/ccstatusline-usage-api.sh"

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
hook_entry = {"hooks": [{"type": "command", "command": notify_command}]}
hooks = settings.setdefault("hooks", {})
for event in ("Notification", "Stop"):
    hooks[event] = [hook_entry]

with open(settings_path, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

echo "Installed Claude Code notifications and status line."
echo "Restart Claude Code to load the updated settings."
