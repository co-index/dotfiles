#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_file="$HOME/.config/starship.toml"

if [[ ! -f "$source_file" ]]; then
  echo "export.sh: $source_file not found; nothing to export" >&2
  exit 1
fi

if [[ -f "$module_dir/starship.toml" ]] && diff -q "$module_dir/starship.toml" "$source_file" >/dev/null 2>&1; then
  echo "starship.toml: unchanged"
else
  echo "starship.toml: importing changes:"
  diff -u "$module_dir/starship.toml" "$source_file" 2>/dev/null || true
fi
cp "$source_file" "$module_dir/starship.toml"
echo "Exported $source_file -> $module_dir/starship.toml"
echo "Review the file for sensitive content before committing."
