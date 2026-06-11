#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_path="$claude_dir/settings.json"
statusline_dir="$HOME/.config/ccstatusline"
bin_dir="$HOME/.local/bin"
state_path="$claude_dir/ccdots-state.json"
plugin_marketplace="co-index/claude-plugins"

# Skips the backup when the existing file already matches the replacement,
# so reruns do not pile up identical .bak.* files.
backup_file() {
  local path="$1"
  local replacement="${2:-}"
  [[ -e "$path" ]] || return 0
  if [[ -n "$replacement" ]] && diff -q "$path" "$replacement" >/dev/null 2>&1; then
    return 0
  fi
  cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
}

# The real ccnotify helper is a shim that references the ccnotify.app
# bundle; unrelated tools that share the name do not.
is_ccnotify_helper() {
  [[ -x "$1" ]] && head -c 4096 "$1" 2>/dev/null | grep -q "ccnotify.app"
}

mkdir -p "$claude_dir" "$statusline_dir" "$bin_dir"

backup_file "$claude_dir/ccstatusline-usage-api.sh" "$repo_dir/scripts/ccstatusline-usage-api.sh"
backup_file "$statusline_dir/settings.json" "$repo_dir/config/ccstatusline-settings.json"
backup_file "$bin_dir/ccdots" "$repo_dir/bin/ccdots"

cp "$repo_dir/scripts/ccstatusline-usage-api.sh" "$claude_dir/ccstatusline-usage-api.sh"
cp "$repo_dir/config/ccstatusline-settings.json" "$statusline_dir/settings.json"
cp "$repo_dir/bin/ccdots" "$bin_dir/ccdots"
chmod +x "$claude_dir/ccstatusline-usage-api.sh" "$bin_dir/ccdots"

# Notifications are provided by the ccnotify Claude Code plugin (single
# source: https://github.com/co-index/claude-plugins). Register it BEFORE
# removing the legacy notify hook, so a failed registration never leaves the
# user without notifications. CCDOTS_SKIP_PLUGIN=1 skips the
# network-dependent plugin setup and treats it as handled (the offline test
# suite sets it).
plugin_ready=0
if [[ "${CCDOTS_SKIP_PLUGIN:-}" == "1" ]]; then
  plugin_ready=1
elif command -v claude >/dev/null 2>&1; then
  if ! claude plugin marketplace list 2>/dev/null | grep -q " co-index$"; then
    claude plugin marketplace add "$plugin_marketplace" \
      || echo "Warning: could not add the co-index plugin marketplace."
  fi
  if ! claude plugin list 2>/dev/null | grep -q "ccnotify@co-index"; then
    claude plugin install ccnotify@co-index \
      || echo "Warning: could not install the ccnotify plugin."
  fi
  if claude plugin list 2>/dev/null | grep -q "ccnotify@co-index"; then
    plugin_ready=1
  fi
else
  echo "Note: claude CLI not found; install the notification plugin from Claude Code:"
  echo "  /plugin marketplace add $plugin_marketplace"
  echo "  /plugin install ccnotify@co-index"
fi

# Migration from earlier layouts: the version manager used to be installed
# as ~/.local/bin/ccnotify (the name now belongs to the standalone notifier,
# https://github.com/co-index/ccnotify), notifications used to come from
# a ClaudeNotifier.app compiled into the Claude config dir, and the notify
# hook used to live in settings.json instead of the ccnotify plugin. The
# legacy hook is only removed once the plugin is in place, so notifications
# never go dark in between.
old_hook="$claude_dir/hooks/notify-macos.sh"
if [[ -f "$old_hook" ]]; then
  if [[ "$plugin_ready" == "1" ]]; then
    cp "$old_hook" "$old_hook.bak.$(date +%Y%m%d-%H%M%S)"
    rm -f "$old_hook"
    echo "Removed the old notify hook (notifications now come from the ccnotify plugin)."
  else
    echo "Keeping the existing notify hook until the ccnotify plugin is installed;"
    echo "rerun this installer once the plugin commands above have succeeded."
  fi
fi
if [[ -f "$bin_dir/ccnotify" ]] && head -c 4096 "$bin_dir/ccnotify" | grep -q "version manager for Claude Code"; then
  rm -f "$bin_dir/ccnotify"
  echo "Removed the old $bin_dir/ccnotify (the version manager is now ccdots)."
fi
if [[ -f "$claude_dir/ccnotify-state.json" ]]; then
  if [[ -f "$state_path" ]]; then
    backup_file "$claude_dir/ccnotify-state.json"
    rm -f "$claude_dir/ccnotify-state.json"
  else
    mv "$claude_dir/ccnotify-state.json" "$state_path"
  fi
fi
if [[ -d "$claude_dir/ClaudeNotifier.app" ]]; then
  rm -rf "$claude_dir/ClaudeNotifier.app"
  echo "Removed the old ClaudeNotifier.app (notifications now use ccnotify)."
fi

# settings.json is merged in place, so the backup is decided inside the
# merge: only when the merge actually changes the file.
PLUGIN_READY="$plugin_ready" /usr/bin/python3 - "$settings_path" "$claude_dir" <<'PY'
import datetime
import json
import os
import shutil
import sys

settings_path = sys.argv[1]
claude_dir = sys.argv[2]
plugin_ready = os.environ.get("PLUGIN_READY") == "1"

if os.path.exists(settings_path):
    with open(settings_path, "r", encoding="utf-8") as fh:
        try:
            settings = json.load(fh)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"Invalid JSON in {settings_path}: {exc}")
else:
    settings = {}

original = json.dumps(settings, sort_keys=True)

settings["statusLine"] = {
    "type": "command",
    "command": os.path.join(claude_dir, "ccstatusline-usage-api.sh"),
    "padding": 0,
}


# Notifications now come from the ccnotify plugin; strip the notify hook
# entries that earlier versions of this installer wrote into settings.json,
# keeping any hooks the user added themselves. Skipped while the plugin is
# not yet in place so the legacy hook keeps working.
def is_project_hook(hook):
    return (
        isinstance(hook, dict)
        and isinstance(hook.get("command"), str)
        and hook["command"].endswith("/hooks/notify-macos.sh")
    )


hooks = settings.get("hooks")
if plugin_ready and isinstance(hooks, dict):
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

if json.dumps(settings, sort_keys=True) != original:
    if os.path.exists(settings_path):
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        shutil.copy2(settings_path, f"{settings_path}.bak.{stamp}")
    with open(settings_path, "w", encoding="utf-8") as fh:
        json.dump(settings, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
PY

/usr/bin/python3 - "$state_path" "$repo_dir/bin/ccdots" <<'PY'
import datetime
import json
import os
import sys

state_path = sys.argv[1]
ccdots_path = sys.argv[2]

def default_repo():
    # bin/ccdots is the single configuration point for the repo name;
    # read its GITHUB_REPO default instead of duplicating it here.
    try:
        with open(ccdots_path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line.startswith("GITHUB_REPO="):
                    continue
                value = line[len("GITHUB_REPO="):].strip().strip('"').strip("'")
                if ":-" in value:
                    value = value.split(":-", 1)[1].split("}", 1)[0]
                value = value.strip('"').strip("'")
                if value and "/" in value and not value.startswith("$"):
                    return value
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


def env(name):
    # The CCNOTIFY_* fallbacks keep upgrades driven by the old version
    # manager (pre-rename releases) recording the right version.
    return os.environ.get(f"CCDOTS_{name}") or os.environ.get(f"CCNOTIFY_{name}") or ""


version = env("VERSION")
state = {
    "version": version or "dev",
    "repo": env("REPO") or old.get("repo") or default_repo(),
    "installedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source": "release" if version else "local",
    "previousVersion": env("PREVIOUS_VERSION") or old.get("version"),
}

with open(state_path, "w", encoding="utf-8") as fh:
    json.dump(state, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    echo "Note: $bin_dir is not on your PATH."
    echo "Add this line to your shell profile to use the ccdots command:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac

if ! { is_ccnotify_helper /opt/homebrew/bin/ccnotify \
    || is_ccnotify_helper /usr/local/bin/ccnotify \
    || command -v terminal-notifier >/dev/null 2>&1; }; then
  echo "Note: for clickable notifications, install the ccnotify helper:"
  echo "  brew install co-index/tap/ccnotify"
  echo "Without it, notifications fall back to a non-clickable osascript banner."
fi

echo "Installed Claude Code notifications and status line."
echo "Restart Claude Code to load the updated settings."
