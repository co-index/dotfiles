#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="$HOME/.config"
target="$target_dir/starship.toml"

backup_file() {
  local path="$1"
  local replacement="${2:-}"
  [[ -e "$path" ]] || return 0
  if [[ -n "$replacement" ]] && diff -q "$path" "$replacement" >/dev/null 2>&1; then
    return 0
  fi
  cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
}

mkdir -p "$target_dir"
backup_file "$target" "$module_dir/starship.toml"
cp "$module_dir/starship.toml" "$target"

if ! command -v starship >/dev/null 2>&1; then
  echo "Note: the starship binary is not on your PATH."
  echo "Install it with: brew install starship"
  echo 'Then add this line to your ~/.zshrc: eval "$(starship init zsh)"'
fi

echo "Installed starship configuration to $target"
