#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
modules=(claude vscode starship)

usage() {
  cat <<EOF
dotfiles uninstaller

Usage:
  ./uninstall.sh <module> [<module> ...]
  ./uninstall.sh --all

Modules:
  claude     Remove Claude Code notifications, status line, and ccdots
  vscode     Remove VS Code settings and keybindings (extensions stay)
  starship   Remove the Starship prompt configuration

Examples:
  ./uninstall.sh claude
  ./uninstall.sh vscode starship
  ./uninstall.sh --all

Every file is backed up as <name>.bak.YYYYMMDD-HHMMSS before removal, so
you can restore it by copying the backup over the original name.
EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

selected=()
if [[ "$1" == "--all" ]]; then
  if [[ $# -gt 1 ]]; then
    echo "uninstall.sh: --all takes no further arguments" >&2
    usage >&2
    exit 1
  fi
  selected=("${modules[@]}")
else
  for arg in "$@"; do
    known=0
    for module in "${modules[@]}"; do
      if [[ "$arg" == "$module" ]]; then
        known=1
        break
      fi
    done
    if [[ "$known" -eq 0 ]]; then
      echo "uninstall.sh: unknown module: $arg" >&2
      usage >&2
      exit 1
    fi
    selected+=("$arg")
  done
fi

for module in "${selected[@]}"; do
  echo "==> Uninstalling module: $module"
  rc=0
  bash "$repo_dir/$module/uninstall.sh" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "uninstall.sh: module '$module' failed" >&2
    exit "$rc"
  fi
done

echo "Done. Restart the affected applications to apply the change."
