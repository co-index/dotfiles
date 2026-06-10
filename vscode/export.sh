#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user_dir="$HOME/Library/Application Support/Code/User"

for file in settings.json keybindings.json; do
  if [[ ! -f "$user_dir/$file" ]]; then
    echo "export.sh: $user_dir/$file not found" >&2
    exit 1
  fi
  cp "$user_dir/$file" "$module_dir/$file"
  echo "Exported $file"
done

if command -v code >/dev/null 2>&1; then
  code --list-extensions > "$module_dir/extensions.txt"
  echo "Exported extensions.txt ($(wc -l < "$module_dir/extensions.txt" | tr -d ' ') extensions)"
else
  echo "Note: 'code' CLI not found; extensions.txt left unchanged."
fi

echo "Review settings.json for sensitive content (tokens, proxies, private hosts) before committing."
