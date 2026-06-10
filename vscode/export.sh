#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user_dir="$HOME/Library/Application Support/Code/User"

for file in settings.json keybindings.json; do
  if [[ ! -f "$user_dir/$file" ]]; then
    echo "export.sh: $user_dir/$file not found" >&2
    exit 1
  fi
  if [[ -f "$module_dir/$file" ]] && diff -q "$module_dir/$file" "$user_dir/$file" >/dev/null 2>&1; then
    echo "$file: unchanged"
  else
    echo "$file: importing changes:"
    diff -u "$module_dir/$file" "$user_dir/$file" 2>/dev/null || true
  fi
  cp "$user_dir/$file" "$module_dir/$file"
  echo "Exported $file"
done

if command -v code >/dev/null 2>&1; then
  new_extensions="$(code --list-extensions)"
  if [[ -f "$module_dir/extensions.txt" ]] \
    && diff -q "$module_dir/extensions.txt" <(printf '%s\n' "$new_extensions") >/dev/null 2>&1; then
    echo "extensions.txt: unchanged"
  else
    echo "extensions.txt: importing changes (lines removed here disappear from the manifest):"
    diff -u "$module_dir/extensions.txt" <(printf '%s\n' "$new_extensions") 2>/dev/null || true
  fi
  printf '%s\n' "$new_extensions" > "$module_dir/extensions.txt"
  echo "Exported extensions.txt ($(wc -l < "$module_dir/extensions.txt" | tr -d ' ') extensions)"
else
  echo "Note: 'code' CLI not found; extensions.txt left unchanged."
fi

echo "Review settings.json for sensitive content (tokens, proxies, private hosts) before committing."
