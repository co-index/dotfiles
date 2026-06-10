#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.config/starship.toml"

if [[ -e "$target" ]]; then
  cp "$target" "$target.bak.$(date +%Y%m%d-%H%M%S)"
  rm -f "$target"
  echo "Removed $target (backup kept next to it)."
else
  echo "Nothing to remove: $target does not exist."
fi

echo 'If you added it for this module, remove this line from your ~/.zshrc:'
echo '  eval "$(starship init zsh)"'
