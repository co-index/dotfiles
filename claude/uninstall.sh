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

# The notification plugin is registered with Claude Code, not copied into
# place, so it is removed through the plugin manager. CCDOTS_SKIP_PLUGIN=1
# skips this (the test suite sets it).
if [[ "${CCDOTS_SKIP_PLUGIN:-}" != "1" ]] && command -v claude >/dev/null 2>&1; then
  if claude plugin list 2>/dev/null | grep -q "ccnotify@co-index"; then
    claude plugin uninstall ccnotify@co-index \
      || echo "Warning: could not uninstall the ccnotify plugin."
  fi
  if claude plugin marketplace list 2>/dev/null | grep -q " co-index$"; then
    claude plugin marketplace remove co-index \
      || echo "Warning: could not remove the co-index marketplace."
  fi
fi

# Leftover from older installs that compiled a notifier app; no backup needed.
if [[ -d "$claude_dir/ClaudeNotifier.app" ]]; then
  rm -rf "$claude_dir/ClaudeNotifier.app"
  echo "Removed $claude_dir/ClaudeNotifier.app."
fi

remove_file "$claude_dir/hooks/notify-macos.sh"
remove_file "$claude_dir/ccstatusline-usage-api.sh"
remove_file "$statusline_dir/settings.json"
remove_file "$bin_dir/ccdots"
remove_file "$claude_dir/ccdots-state.json"

# Older installs used the ccnotify name for the version manager; only touch
# it if it is actually ours (the standalone ccnotify notifier is unrelated
# and managed by brew).
if [[ -f "$bin_dir/ccnotify" ]] && head -c 4096 "$bin_dir/ccnotify" | grep -q "version manager for Claude Code"; then
  remove_file "$bin_dir/ccnotify"
fi
remove_file "$claude_dir/ccnotify-state.json"

if [[ -f "$settings_path" ]]; then
  # Backs up and rewrites settings.json only when project entries are
  # actually present, so rerunning the uninstaller stays quiet and does
  # not pile up identical backups.
  /usr/bin/python3 - "$settings_path" <<'PY'
import datetime
import json
import shutil
import sys

settings_path = sys.argv[1]
with open(settings_path, "r", encoding="utf-8") as fh:
    try:
        settings = json.load(fh)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {settings_path}: {exc}")

original = json.dumps(settings, sort_keys=True)

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

if json.dumps(settings, sort_keys=True) == original:
    print(f"No project settings found in {settings_path}; left unchanged.")
else:
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    shutil.copy2(settings_path, f"{settings_path}.bak.{stamp}")
    with open(settings_path, "w", encoding="utf-8") as fh:
        json.dump(settings, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(
        f"Removed the project statusLine and notification hooks from {settings_path} "
        "(backup kept next to it)."
    )
PY
fi

echo "Uninstalled Claude Code notifications and status line."
echo "Restart Claude Code to apply the change."
