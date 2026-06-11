#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user_dir="$HOME/Library/Application Support/Code/User"

backup_file() {
  local path="$1"
  local replacement="${2:-}"
  [[ -e "$path" ]] || return 0
  if [[ -n "$replacement" ]] && diff -q "$path" "$replacement" >/dev/null 2>&1; then
    return 0
  fi
  cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
}

mkdir -p "$user_dir"

for file in settings.json keybindings.json; do
  backup_file "$user_dir/$file" "$module_dir/$file"
  cp "$module_dir/$file" "$user_dir/$file"
done

# Cursor also registers a `code` shim, so a bare `command -v code` can send
# extensions to Cursor instead of VS Code. Prefer the CLI inside the VS Code
# bundle and reject shims that resolve into Cursor.app. DOTFILES_CODE_BIN
# forces a specific CLI (set it empty to skip extension installs).
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
  failed=0
  installed=0
  while IFS= read -r extension || [[ -n "$extension" ]]; do
    [[ -z "$extension" || "$extension" == \#* ]] && continue
    if output="$("$code_cli" --install-extension "$extension" 2>&1)"; then
      installed=$((installed + 1))
    else
      echo "Warning: failed to install extension: $extension"
      printf '%s\n' "$output" | grep -v '^[[:space:]]*$' | tail -n 2 | sed 's/^/    /' || true
      failed=$((failed + 1))
    fi
  done < "$module_dir/extensions.txt"
  echo "Extensions: $installed installed, $failed failed (via $code_cli)."
elif [[ -n "$cursor_shim" ]]; then
  echo "Note: the 'code' on your PATH ($cursor_shim) belongs to Cursor and VS Code's own CLI was not found; skipped installing extensions so they do not land in Cursor."
  echo "In VS Code run: Command Palette -> Shell Command: Install 'code' command in PATH."
  echo "Then rerun: bash $module_dir/install.sh"
else
  echo "Note: the 'code' CLI is not on your PATH; skipped installing extensions."
  echo "Enable it in VS Code: Command Palette -> Shell Command: Install 'code' command in PATH."
  echo "Then rerun: bash $module_dir/install.sh"
fi

echo "Installed VS Code settings and keybindings to $user_dir"
