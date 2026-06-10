#!/usr/bin/env bash
set -euo pipefail

user_dir="$HOME/Library/Application Support/Code/User"

for file in settings.json keybindings.json; do
  path="$user_dir/$file"
  if [[ -e "$path" ]]; then
    cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
    rm -f "$path"
    echo "Removed $path (backup kept next to it)."
  else
    echo "Nothing to remove: $path does not exist."
  fi
done

echo "Extensions are never uninstalled by this module; remove unwanted ones in VS Code."
