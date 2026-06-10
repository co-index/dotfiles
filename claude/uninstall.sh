#!/usr/bin/env bash
set -euo pipefail

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_path="$claude_dir/settings.json"
statusline_dir="$HOME/.config/ccstatusline"
bin_dir="$HOME/.local/bin"

remove_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
    rm -f "$path"
    echo "Removed $path (backup kept next to it)."
  fi
}

remove_file "$claude_dir/hooks/notify-macos.sh"
remove_file "$claude_dir/ccstatusline-usage-api.sh"
remove_file "$statusline_dir/settings.json"
remove_file "$bin_dir/ccnotify"
remove_file "$claude_dir/ccnotify-state.json"

if [[ -f "$settings_path" ]]; then
  cp "$settings_path" "$settings_path.bak.$(date +%Y%m%d-%H%M%S)"
  /usr/bin/python3 - "$settings_path" <<'PY'
import json
import sys

settings_path = sys.argv[1]
with open(settings_path, "r", encoding="utf-8") as fh:
    try:
        settings = json.load(fh)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {settings_path}: {exc}")

status = settings.get("statusLine")
if (
    isinstance(status, dict)
    and isinstance(status.get("command"), str)
    and status["command"].endswith("/ccstatusline-usage-api.sh")
):
    del settings["statusLine"]


def is_project_hook(hook):
    return (
        isinstance(hook, dict)
        and isinstance(hook.get("command"), str)
        and hook["command"].endswith("/hooks/notify-macos.sh")
    )


hooks = settings.get("hooks")
if isinstance(hooks, dict):
    for event in ("Notification", "Stop"):
        entries = hooks.get(event)
        if not isinstance(entries, list):
            continue
        kept = []
        for entry in entries:
            if isinstance(entry, dict) and isinstance(entry.get("hooks"), list):
                entry["hooks"] = [h for h in entry["hooks"] if not is_project_hook(h)]
                if not entry["hooks"]:
                    continue
            kept.append(entry)
        if kept:
            hooks[event] = kept
        else:
            hooks.pop(event, None)
    if not hooks:
        settings.pop("hooks", None)

with open(settings_path, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
  echo "Removed the project statusLine and notification hooks from $settings_path."
fi

echo "Uninstalled Claude Code notifications and status line."
echo "Restart Claude Code to apply the change."
