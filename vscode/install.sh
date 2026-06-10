#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user_dir="$HOME/Library/Application Support/Code/User"

backup_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
  fi
}

mkdir -p "$user_dir"

for file in settings.json keybindings.json; do
  backup_file "$user_dir/$file"
  cp "$module_dir/$file" "$user_dir/$file"
done

if command -v code >/dev/null 2>&1; then
  failed=0
  installed=0
  while IFS= read -r extension; do
    [[ -z "$extension" || "$extension" == \#* ]] && continue
    if code --install-extension "$extension" >/dev/null 2>&1; then
      installed=$((installed + 1))
    else
      echo "Warning: failed to install extension: $extension"
      failed=$((failed + 1))
    fi
  done < "$module_dir/extensions.txt"
  echo "Extensions: $installed installed, $failed failed."
else
  echo "Note: the 'code' CLI is not on your PATH; skipped installing extensions."
  echo "Enable it in VS Code: Command Palette -> Shell Command: Install 'code' command in PATH."
  echo "Then rerun: bash $module_dir/install.sh"
fi

echo "Installed VS Code settings and keybindings to $user_dir"
