#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
modules=(claude vscode starship)

usage() {
  cat <<EOF
dotfiles installer

Usage:
  ./install.sh <module> [<module> ...]
  ./install.sh --all

Modules:
  claude     Claude Code macOS notifications, status line, and ccnotify
  vscode     VS Code settings, keybindings, and extensions
  starship   Starship prompt configuration

Examples:
  ./install.sh claude
  ./install.sh vscode starship
  ./install.sh --all

Check the prerequisites in README.md and each module's README before
installing. Existing files are backed up as <name>.bak.YYYYMMDD-HHMMSS.
EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

selected=()
if [[ "$1" == "--all" ]]; then
  if [[ $# -gt 1 ]]; then
    echo "install.sh: --all takes no further arguments" >&2
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
      echo "install.sh: unknown module: $arg" >&2
      usage >&2
      exit 1
    fi
    selected+=("$arg")
  done
fi

for module in "${selected[@]}"; do
  echo "==> Installing module: $module"
  if ! bash "$repo_dir/$module/install.sh"; then
    echo "install.sh: module '$module' failed" >&2
    exit 1
  fi
done

echo "Done. Restart the affected applications to load the new configuration."
