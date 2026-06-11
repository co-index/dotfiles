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

# Cursor also registers a `code` shim; exporting through it would overwrite
# extensions.txt with Cursor's extension list. Same probe as install.sh:
# prefer the VS Code bundle CLI, reject Cursor shims, DOTFILES_CODE_BIN wins.
code_cli=""
cursor_shim=""
locate_code_cli() {
  if [[ -n "${DOTFILES_CODE_BIN+set}" ]]; then
    [[ -n "$DOTFILES_CODE_BIN" && -x "$DOTFILES_CODE_BIN" ]] && code_cli="$DOTFILES_CODE_BIN"
    return 0
  fi
  local candidate resolved
  for candidate in \
    "${DOTFILES_VSCODE_BUNDLE_CLI:-/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code}" \
    "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
    if [[ -x "$candidate" ]]; then
      code_cli="$candidate"
      return 0
    fi
  done
  candidate="$(command -v code 2>/dev/null || true)"
  [[ -n "$candidate" ]] || return 0
  resolved="$(readlink -f "$candidate" 2>/dev/null || true)"
  if [[ "${resolved:-$candidate}" == *[Cc]ursor* ]]; then
    cursor_shim="$candidate"
    return 0
  fi
  code_cli="$candidate"
}
locate_code_cli

if [[ -n "$code_cli" ]]; then
  new_extensions="$("$code_cli" --list-extensions)"
  if [[ -f "$module_dir/extensions.txt" ]] \
    && diff -q "$module_dir/extensions.txt" <(printf '%s\n' "$new_extensions") >/dev/null 2>&1; then
    echo "extensions.txt: unchanged"
  else
    echo "extensions.txt: importing changes (lines removed here disappear from the manifest):"
    diff -u "$module_dir/extensions.txt" <(printf '%s\n' "$new_extensions") 2>/dev/null || true
  fi
  printf '%s\n' "$new_extensions" > "$module_dir/extensions.txt"
  echo "Exported extensions.txt ($(wc -l < "$module_dir/extensions.txt" | tr -d ' ') extensions)"
elif [[ -n "$cursor_shim" ]]; then
  echo "Note: the 'code' on your PATH ($cursor_shim) belongs to Cursor; extensions.txt left unchanged."
else
  echo "Note: 'code' CLI not found; extensions.txt left unchanged."
fi

echo "Review settings.json for sensitive content (tokens, proxies, private hosts) before committing."
