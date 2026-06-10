# Dotfiles Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the repository into a modular, open-source `dotfiles` repo: existing Claude Code setup moves to `claude/`, new `vscode/` and `starship/` modules are added, with a top-level module-dispatching installer and bilingual prerequisite-first documentation.

**Architecture:** Per-module directories each own an `install.sh` (copy + timestamped backup) and, for vscode/starship, an `export.sh` (machine → repo). A thin top-level `install.sh` dispatches to module installers. `scripts/test.sh` stays the single offline test entry point covering every module. `claude/bin/ccnotify` keeps managing only the claude module (it now runs `claude/install.sh` from downloaded archives).

**Tech Stack:** bash (`set -euo pipefail`, macOS bash 3.2-compatible), `/usr/bin/python3` heredocs for JSON (no jq). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-10-dotfiles-restructure-design.md`

---

## ⚠️ Safety rules for every task

- NEVER run any `install.sh` against the real HOME. Always `HOME="$(mktemp -d)"` (or a subdir of the suite's `$tmp_home`) plus `CLAUDE_CONFIG_DIR` for claude installs. `bash scripts/test.sh` is safe — it self-isolates.
- NEVER run `vscode/export.sh` / `starship/export.sh` against the repo module dirs during tests — they overwrite repo files. Tests copy the script to a scratch dir first (the test code below already does this).
- Exception: Task 6 (seeding) deliberately READS the real HOME (read-only `cp` FROM it). It still never writes outside the repo.

## File Structure (end state)

| Path | Status | Responsibility |
|---|---|---|
| `install.sh` | Create | Top-level dispatcher: usage, module validation, sequential module installs |
| `scripts/test.sh` | Modify | Offline suite for all modules (paths updated; new sections per module) |
| `claude/install.sh` etc. | Move | Entire existing claude setup via `git mv` (history preserved) |
| `claude/bin/ccnotify` | Modify | Archive verification/run path: `install.sh` → `claude/install.sh` |
| `claude/README.md` | Create | Detailed bilingual claude docs (moved from root README, paths updated) |
| `vscode/install.sh`, `vscode/export.sh` | Create | Settings/keybindings copy + extension install; reverse export |
| `vscode/settings.json`, `keybindings.json`, `extensions.txt` | Create | Placeholders in Task 4, real config seeded in Task 6 |
| `starship/install.sh`, `starship/export.sh`, `starship/starship.toml` | Create | Prompt config install/export; placeholder then seeded |
| `vscode/README.md`, `starship/README.md` | Create | Bilingual module docs, prerequisite-first |
| `README.md` | Rewrite | Bilingual repo overview: module table, prerequisites, quick start |

Conventions: every script starts `#!/usr/bin/env bash` + `set -euo pipefail`; backups use `.bak.$(date +%Y%m%d-%H%M%S)`; commit messages are short imperative sentences without prefixes; suite success ends with `All checks passed.` and exit 0.

---

### Task 1: Move the claude module via git mv

**Files:**
- Move: `install.sh` → `claude/install.sh`; `bin/` → `claude/bin/`; `scripts/notify-macos.sh`, `scripts/ccstatusline-usage-api.sh` → `claude/scripts/`; `config/` → `claude/config/`
- Modify: `claude/bin/ccnotify` (2 path references + error message), `scripts/test.sh` (path updates)

- [ ] **Step 1: Move files with history**

```bash
mkdir -p claude/scripts
git mv install.sh claude/install.sh
git mv bin claude/bin
git mv scripts/notify-macos.sh claude/scripts/notify-macos.sh
git mv scripts/ccstatusline-usage-api.sh claude/scripts/ccstatusline-usage-api.sh
git mv config claude/config
rmdir outputs 2>/dev/null || true
```

`scripts/test.sh` stays at the top level. `claude/install.sh` needs NO internal path edits: it resolves everything relative to its own location via `BASH_SOURCE`, and `scripts/`, `config/`, `bin/` moved along with it.

- [ ] **Step 2: Update `claude/bin/ccnotify` for the new archive layout**

In `install_version`, replace:

```bash
  if [[ -z "$src_dir" || ! -f "$src_dir/install.sh" ]]; then
    die "version $version does not contain install.sh; cannot install it"
  fi
```

with:

```bash
  if [[ -z "$src_dir" || ! -f "$src_dir/claude/install.sh" ]]; then
    die "version $version does not contain claude/install.sh; cannot install it"
  fi
```

and replace:

```bash
       bash "$src_dir/install.sh"; then
```

with:

```bash
       bash "$src_dir/claude/install.sh"; then
```

- [ ] **Step 3: Update paths in `scripts/test.sh`**

Apply exactly these substitutions (each old string appears at least once; update every occurrence):

| Old | New |
|---|---|
| `"$repo_dir/install.sh"` | `"$repo_dir/claude/install.sh"` |
| `bash -n install.sh` (check label) | `bash -n claude/install.sh` |
| `"$repo_dir/scripts/notify-macos.sh"` | `"$repo_dir/claude/scripts/notify-macos.sh"` |
| `bash -n scripts/notify-macos.sh` (label) | `bash -n claude/scripts/notify-macos.sh` |
| `"$repo_dir/scripts/ccstatusline-usage-api.sh"` | `"$repo_dir/claude/scripts/ccstatusline-usage-api.sh"` |
| `bash -n scripts/ccstatusline-usage-api.sh` (label) | `bash -n claude/scripts/ccstatusline-usage-api.sh` |
| `"$repo_dir/config/claude-settings.example.json"` | `"$repo_dir/claude/config/claude-settings.example.json"` |
| `"$repo_dir/config/ccstatusline-settings.json"` | `"$repo_dir/claude/config/ccstatusline-settings.json"` |
| `"$repo_dir/bin/ccnotify"` | `"$repo_dir/claude/bin/ccnotify"` |
| `bash -n bin/ccnotify` (label) | `bash -n claude/bin/ccnotify` |

- [ ] **Step 4: Run the suite**

Run: `bash scripts/test.sh`
Expected: all `ok:`, `All checks passed.`, exit 0. (The suite still calls `claude/install.sh` directly; the dispatcher arrives in Task 2.)

- [ ] **Step 5: Verify history survived the move**

Run: `git log --oneline --follow claude/install.sh | tail -2`
Expected: shows the original commits (e.g. `Share reusable Claude Code notification setup`).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Move Claude Code setup into claude module directory"
```

---

### Task 2: Top-level installer dispatcher

**Files:**
- Create: `install.sh` (repo root)
- Modify: `scripts/test.sh`

- [ ] **Step 1: Add failing tests**

In `scripts/test.sh`, insert a new section immediately after the `== Syntax and config checks ==` section (i.e. after the last `check "json: ..."` line) and before `== Installer behavior (temporary HOME) ==`:

```bash
echo "== Top-level installer =="
check "bash -n install.sh" bash -n "$repo_dir/install.sh"
check "no args prints usage and exits 0" bash "$repo_dir/install.sh"
usage_output="$(bash "$repo_dir/install.sh" 2>/dev/null || true)"
if grep -q "Usage:" <<<"$usage_output" && grep -q "claude" <<<"$usage_output"; then
  echo "ok: usage lists modules"
else
  echo "FAIL: usage lists modules"
  failures=$((failures + 1))
fi
expect_fail "unknown module fails" bash "$repo_dir/install.sh" no-such-module
```

Also change the existing scratch-HOME claude install invocations to go through the dispatcher — replace BOTH occurrences of:

```bash
env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/claude/install.sh"
```

with:

```bash
env HOME="$tmp_home" CLAUDE_CONFIG_DIR="$test_claude_dir" bash "$repo_dir/install.sh" claude
```

(these are the `check "install.sh runs"` and `check "install.sh reruns"` lines; leave the third, release-style invocation `CCNOTIFY_VERSION="v9.9.9" ... bash "$repo_dir/claude/install.sh"` pointing at the module script — that simulates what ccnotify itself executes).

- [ ] **Step 2: Run to verify red**

Run: `bash scripts/test.sh`
Expected: the new `Top-level installer` checks FAIL (no root `install.sh` exists), the two dispatcher-routed install checks FAIL, and the downstream `Installer behavior` assertions that depend on an installed scratch HOME (hook installed, settings merged, ccnotify/state checks) FAIL as well. Exit 1. (`expect_fail "unknown module fails"` shows `ok:` because a missing script exits non-zero — fine.)

- [ ] **Step 3: Write `install.sh`**

```bash
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
```

Note for bash 3.2 + `set -u`: `selected` is always non-empty when the loop is reached (we exit earlier otherwise), so `"${selected[@]}"` is safe.

- [ ] **Step 4: Run to verify green**

```bash
chmod +x install.sh
bash scripts/test.sh
```

Expected: all `ok:`, `All checks passed.`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add install.sh scripts/test.sh
git commit -m "Add top-level module installer"
```

---

### Task 3: starship module

**Files:**
- Create: `starship/install.sh`, `starship/export.sh`, `starship/starship.toml` (placeholder)
- Modify: `scripts/test.sh`

- [ ] **Step 1: Add failing tests**

In `scripts/test.sh`, insert before the final `echo` / failure-count block:

```bash
echo "== starship module =="
check "bash -n starship/install.sh" bash -n "$repo_dir/starship/install.sh"
check "bash -n starship/export.sh" bash -n "$repo_dir/starship/export.sh"
check "starship.toml exists and is non-empty" test -s "$repo_dir/starship/starship.toml"

starship_home="$tmp_home/starship-home"
mkdir -p "$starship_home"
check "starship install runs" env HOME="$starship_home" bash "$repo_dir/starship/install.sh"
check "starship.toml installed" test -f "$starship_home/.config/starship.toml"
check "starship install reruns" env HOME="$starship_home" bash "$repo_dir/starship/install.sh"
starship_backups="$(find "$starship_home/.config" -maxdepth 1 -name 'starship.toml.bak.*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$starship_backups" -ge 1 ]]; then
  echo "ok: starship rerun creates backup"
else
  echo "FAIL: starship rerun creates backup"
  failures=$((failures + 1))
fi

starship_export_home="$tmp_home/starship-export-home"
mkdir -p "$starship_export_home/.config"
printf '# exported test config\n' > "$starship_export_home/.config/starship.toml"
starship_module_copy="$tmp_home/starship-module-copy"
mkdir -p "$starship_module_copy"
cp "$repo_dir/starship/export.sh" "$starship_module_copy/export.sh"
check "starship export runs" env HOME="$starship_export_home" bash "$starship_module_copy/export.sh"
check "starship export copied file" grep -q "exported test config" "$starship_module_copy/starship.toml"
expect_fail "starship export fails without source" \
  env HOME="$tmp_home/starship-missing-home" bash "$starship_module_copy/export.sh"
```

(`$tmp_home` already exists with an EXIT-trap cleanup, so no extra rm is needed.)

- [ ] **Step 2: Run to verify red**

Run: `bash scripts/test.sh`
Expected: the starship `check` lines FAIL (files missing); exit 1.

- [ ] **Step 3: Write `starship/install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="$HOME/.config"
target="$target_dir/starship.toml"

backup_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    cp "$path" "$path.bak.$(date +%Y%m%d-%H%M%S)"
  fi
}

mkdir -p "$target_dir"
backup_file "$target"
cp "$module_dir/starship.toml" "$target"

if ! command -v starship >/dev/null 2>&1; then
  echo "Note: the starship binary is not on your PATH."
  echo "Install it with: brew install starship"
  echo 'Then add this line to your ~/.zshrc: eval "$(starship init zsh)"'
fi

echo "Installed starship configuration to $target"
```

- [ ] **Step 4: Write `starship/export.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_file="$HOME/.config/starship.toml"

if [[ ! -f "$source_file" ]]; then
  echo "export.sh: $source_file not found; nothing to export" >&2
  exit 1
fi

cp "$source_file" "$module_dir/starship.toml"
echo "Exported $source_file -> $module_dir/starship.toml"
echo "Review the file for sensitive content before committing."
```

- [ ] **Step 5: Write the placeholder `starship/starship.toml`**

```toml
# Starship prompt configuration.
# Placeholder content; replaced by the owner's real config during seeding.
```

- [ ] **Step 6: Run to verify green**

```bash
chmod +x starship/install.sh starship/export.sh
bash scripts/test.sh
```

Expected: all `ok:`, `All checks passed.`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add starship scripts/test.sh
git commit -m "Add starship prompt module"
```

---

### Task 4: vscode module

**Files:**
- Create: `vscode/install.sh`, `vscode/export.sh`, `vscode/settings.json` + `keybindings.json` + `extensions.txt` (placeholders)
- Modify: `scripts/test.sh`

- [ ] **Step 1: Add the JSONC validation helper to `scripts/test.sh`**

VS Code settings files are JSONC (they may contain `//` comments and trailing commas), so plain `json.tool` would false-fail on real seeded config. Insert this helper right after the `expect_fail()` function definition:

```bash
jsonc_valid() {
  /usr/bin/python3 - "$1" <<'PY'
import json
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    text = fh.read()
text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
text = re.sub(r",\s*([}\]])", r"\1", text)
json.loads(text)
PY
}
```

- [ ] **Step 2: Add failing tests**

Insert before the final `echo` / failure-count block (after the starship section):

```bash
echo "== vscode module =="
check "bash -n vscode/install.sh" bash -n "$repo_dir/vscode/install.sh"
check "bash -n vscode/export.sh" bash -n "$repo_dir/vscode/export.sh"
check "vscode settings.json is valid JSON(C)" jsonc_valid "$repo_dir/vscode/settings.json"
check "vscode keybindings.json is valid JSON(C)" jsonc_valid "$repo_dir/vscode/keybindings.json"
check "vscode extensions.txt exists" test -f "$repo_dir/vscode/extensions.txt"

vscode_home="$tmp_home/vscode-home"
mkdir -p "$vscode_home"
vscode_user_dir="$vscode_home/Library/Application Support/Code/User"
vscode_install_output="$(env HOME="$vscode_home" PATH="/usr/bin:/bin" bash "$repo_dir/vscode/install.sh" 2>&1)" \
  && vscode_install_ok=1 || vscode_install_ok=0
if [[ "$vscode_install_ok" -eq 1 ]]; then
  echo "ok: vscode install runs without code CLI"
else
  echo "FAIL: vscode install runs without code CLI"
  failures=$((failures + 1))
fi
if grep -q "skipped installing extensions" <<<"$vscode_install_output"; then
  echo "ok: vscode install warns about missing code CLI"
else
  echo "FAIL: vscode install warns about missing code CLI"
  failures=$((failures + 1))
fi
check "vscode settings installed" test -f "$vscode_user_dir/settings.json"
check "vscode keybindings installed" test -f "$vscode_user_dir/keybindings.json"
check "vscode install reruns" env HOME="$vscode_home" PATH="/usr/bin:/bin" bash "$repo_dir/vscode/install.sh"
vscode_backups="$(find "$vscode_user_dir" -maxdepth 1 -name 'settings.json.bak.*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$vscode_backups" -ge 1 ]]; then
  echo "ok: vscode rerun creates backup"
else
  echo "FAIL: vscode rerun creates backup"
  failures=$((failures + 1))
fi

vscode_export_home="$tmp_home/vscode-export-home"
mkdir -p "$vscode_export_home/Library/Application Support/Code/User"
printf '{"export": "test"}\n' > "$vscode_export_home/Library/Application Support/Code/User/settings.json"
printf '[]\n' > "$vscode_export_home/Library/Application Support/Code/User/keybindings.json"
vscode_module_copy="$tmp_home/vscode-module-copy"
mkdir -p "$vscode_module_copy"
cp "$repo_dir/vscode/export.sh" "$vscode_module_copy/export.sh"
check "vscode export runs (no code CLI)" \
  env HOME="$vscode_export_home" PATH="/usr/bin:/bin" bash "$vscode_module_copy/export.sh"
check "vscode export copied settings" grep -q '"export": "test"' "$vscode_module_copy/settings.json"
expect_fail "vscode export fails without source" \
  env HOME="$tmp_home/vscode-missing-home" PATH="/usr/bin:/bin" bash "$vscode_module_copy/export.sh"
```

- [ ] **Step 3: Run to verify red**

Run: `bash scripts/test.sh`
Expected: the vscode `check`/grep lines FAIL (files missing); exit 1.

- [ ] **Step 4: Write `vscode/install.sh`**

```bash
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
```

- [ ] **Step 5: Write `vscode/export.sh`**

```bash
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
```

- [ ] **Step 6: Write the placeholder content files**

`vscode/settings.json`:

```json
{}
```

`vscode/keybindings.json`:

```json
[]
```

`vscode/extensions.txt`:

```text
# One extension id per line. Placeholder; replaced during seeding.
```

- [ ] **Step 7: Run to verify green**

```bash
chmod +x vscode/install.sh vscode/export.sh
bash scripts/test.sh
```

Expected: all `ok:`, `All checks passed.`, exit 0.

- [ ] **Step 8: Commit**

```bash
git add vscode scripts/test.sh
git commit -m "Add vscode settings module"
```

---

### Task 5: --all integration test

**Files:**
- Modify: `scripts/test.sh`

- [ ] **Step 1: Add failing test**

Insert before the final `echo` / failure-count block (after the vscode section):

```bash
echo "== install --all =="
all_home="$tmp_home/all-home"
mkdir -p "$all_home/.claude"
check "install --all runs" \
  env HOME="$all_home" CLAUDE_CONFIG_DIR="$all_home/.claude" PATH="/usr/bin:/bin" \
  bash "$repo_dir/install.sh" --all
check "all: claude hook installed" test -x "$all_home/.claude/hooks/notify-macos.sh"
check "all: ccnotify installed" test -x "$all_home/.local/bin/ccnotify"
check "all: vscode settings installed" test -f "$all_home/Library/Application Support/Code/User/settings.json"
check "all: starship config installed" test -f "$all_home/.config/starship.toml"
```

- [ ] **Step 2: Run — likely already green**

Run: `bash scripts/test.sh`
Expected: all `ok:`, exit 0 (everything `--all` needs already exists). If anything fails, fix before committing — this is the integration check for the dispatcher + all three modules.

Note: `--all` with `PATH=/usr/bin:/bin` exercises the claude installer too; its `npx`-dependent script is only copied, never executed, so the restricted PATH is fine.

- [ ] **Step 3: Commit**

```bash
git add scripts/test.sh
git commit -m "Cover install --all in the test suite"
```

---

### Task 6: Seed real configuration (REVIEW GATE — do not blind-commit)

**Files:**
- Modify: `vscode/settings.json`, `vscode/keybindings.json`, `vscode/extensions.txt`, `starship/starship.toml`

This task READS the owner's real config (read-only) and copies it into the repo. It has a mandatory human review gate before commit.

- [ ] **Step 1: Copy real config into the modules**

```bash
cp "$HOME/Library/Application Support/Code/User/settings.json" vscode/settings.json
cp "$HOME/Library/Application Support/Code/User/keybindings.json" vscode/keybindings.json
code --list-extensions > vscode/extensions.txt
cp "$HOME/.config/starship.toml" starship/starship.toml
```

If `code` is not on PATH, report BLOCKED (do not fabricate an extensions list).

- [ ] **Step 2: Sensitive-content scan**

```bash
grep -inE 'token|secret|password|passwd|api[_-]?key|authorization|bearer|credential|proxy' \
  vscode/settings.json vscode/keybindings.json starship/starship.toml || echo "(no keyword hits)"
```

Additionally read `vscode/settings.json` in full (it is small) and note ANY URLs, hostnames, internal service names, usernames, or absolute paths embedding the username. Also check whether `starship/starship.toml` uses Nerd Font glyphs (non-ASCII symbols) — report this fact; Task 7's README needs it.

- [ ] **Step 3: Run the suite**

Run: `bash scripts/test.sh`
Expected: all `ok:` (the JSONC-tolerant validator must accept the real settings.json), exit 0. If validation fails on the real file, report the parse error verbatim — do not edit the user's config to make it pass.

- [ ] **Step 4: STOP and report for review — do NOT commit**

Report status DONE_WITH_CONCERNS listing: every scan hit (or "no hits"), every URL/hostname/username found, the extension count, and the Nerd-Font-glyph answer. The controller shows this to the owner, who decides keep/strip per item. Only after the owner approves does the controller (or a follow-up task) commit:

```bash
git add vscode/settings.json vscode/keybindings.json vscode/extensions.txt starship/starship.toml
git commit -m "Seed vscode and starship config from local machine"
```

---

### Task 7: Documentation — root README + three module READMEs

**Files:**
- Rewrite: `README.md`
- Create: `claude/README.md`, `vscode/README.md`, `starship/README.md`

Every README is bilingual: `## 中文` first, `## English` second, with a `[中文](#中文) | [English](#english)` switcher line under the title — matching the existing convention. Prerequisites come BEFORE install steps in every module README (owner requirement).

- [ ] **Step 1: Create `claude/README.md`**

Move the entire current claude documentation out of the root `README.md`: everything under `## 中文` and `## English` (both full sections) becomes the body of `claude/README.md`, under the new title:

```markdown
# claude — Claude Code macOS notifications and status line

[中文](#中文) | [English](#english)

Claude Code 桌面通知、ccstatusline 状态栏与 ccnotify 版本管理。/ macOS
notifications, a ccstatusline-powered status line, and the ccnotify version
manager for Claude Code.
```

Then apply these textual updates throughout the moved content (both languages):

| Old | New |
|---|---|
| `git clone https://github.com/YOUR_NAME/claude-code-macos-notify-statusline.git` + `cd claude-code-macos-notify-statusline` | `git clone https://github.com/OWNER/dotfiles.git` + `cd dotfiles` |
| `chmod +x install.sh` + `./install.sh` | `./install.sh claude` |
| `CLAUDE_CONFIG_DIR="$HOME/.claude" ./install.sh` | `CLAUDE_CONFIG_DIR="$HOME/.claude" ./install.sh claude` |
| `cp scripts/notify-macos.sh ...` | `cp claude/scripts/notify-macos.sh ...` |
| `cp scripts/ccstatusline-usage-api.sh ...` | `cp claude/scripts/ccstatusline-usage-api.sh ...` |
| `cp config/ccstatusline-settings.json ...` | `cp claude/config/ccstatusline-settings.json ...` |
| `config/claude-settings.example.json` (prose references) | `claude/config/claude-settings.example.json` |
| `修改 config/...` / `Edit config/...` (Customization section) | `claude/config/...` |
| `修改 scripts/...` / `Edit scripts/...` (Customization section) | `claude/scripts/...` |
| `| scripts/notify-macos.sh` (testing pipe) | `| claude/scripts/notify-macos.sh` |
| `| scripts/ccstatusline-usage-api.sh` (testing pipe) | `| claude/scripts/ccstatusline-usage-api.sh` |
| `编辑 bin/ccnotify` / `edit bin/ccnotify` (prose) | `claude/bin/ccnotify` |
| `重新运行 ./install.sh` / `run ./install.sh again` (Customization) | `./install.sh claude` |

All target paths (`~/.claude/...`, `~/.local/bin/ccnotify`, etc.) are unchanged. The 测试/Testing sections keep `bash scripts/test.sh` as-is (the suite stayed at the top level).

- [ ] **Step 2: Rewrite the root `README.md`**

Replace the whole file with:

````markdown
# dotfiles

[中文](#中文) | [English](#english)

Personal macOS development environment configuration, organized as
independently installable modules. Every installer backs up existing files
before overwriting them.

## 中文

### 模块

| 模块 | 内容 | 安装位置 | 额外前置条件 |
|---|---|---|---|
| [claude](claude/README.md) | Claude Code macOS 通知、状态栏、`ccnotify` 版本管理 | `~/.claude`、`~/.config/ccstatusline`、`~/.local/bin` | Claude Code；Node.js + npm |
| [vscode](vscode/README.md) | VS Code settings、keybindings、插件清单 | `~/Library/Application Support/Code/User` | VS Code；装插件需 `code` CLI |
| [starship](starship/README.md) | Starship 终端提示符配置 | `~/.config/starship.toml` | starship |

### 前置条件

所有模块共同要求：

- macOS
- git
- `/usr/bin/python3`（随 Xcode Command Line Tools 提供：`xcode-select --install`）
- curl（macOS 自带）

各模块的额外前置条件见上表，安装前请阅读对应模块 README 的"前置条件"一节。

### 快速开始

```bash
git clone https://github.com/OWNER/dotfiles.git
cd dotfiles
./install.sh            # 查看用法和模块列表，不会安装任何东西
./install.sh claude     # 安装单个模块
./install.sh --all      # 安装全部模块
```

安装脚本覆盖已有文件前会生成同目录备份，格式如 `settings.json.bak.20260610-153000`。
安装完成后重启对应应用（Claude Code / VS Code / 终端）。

### 更新

```bash
git pull
./install.sh <module>
```

claude 模块还提供 `ccnotify` 命令，按 GitHub Release 检查、升级和回滚版本，
详见 [claude/README.md](claude/README.md)。

### 把本机改动收回仓库

vscode 和 starship 模块提供导出脚本：

```bash
bash vscode/export.sh
bash starship/export.sh
```

导出后提交前，请检查文件中是否含有密钥、代理地址等私密内容。

### 测试

```bash
bash scripts/test.sh
```

全部测试离线运行，使用临时目录，不会改动你的真实配置。

## English

### Modules

| Module | Contents | Installs to | Extra prerequisites |
|---|---|---|---|
| [claude](claude/README.md) | Claude Code macOS notifications, status line, `ccnotify` version manager | `~/.claude`, `~/.config/ccstatusline`, `~/.local/bin` | Claude Code; Node.js + npm |
| [vscode](vscode/README.md) | VS Code settings, keybindings, extension list | `~/Library/Application Support/Code/User` | VS Code; `code` CLI for extensions |
| [starship](starship/README.md) | Starship prompt configuration | `~/.config/starship.toml` | starship |

### Prerequisites

Shared by all modules:

- macOS
- git
- `/usr/bin/python3` (ships with the Xcode Command Line Tools: `xcode-select --install`)
- curl (bundled with macOS)

Each module lists its extra prerequisites in the table above; read the
module README's Prerequisites section before installing.

### Quick Start

```bash
git clone https://github.com/OWNER/dotfiles.git
cd dotfiles
./install.sh            # print usage and the module list; installs nothing
./install.sh claude     # install one module
./install.sh --all      # install everything
```

Installers back up any file they overwrite next to the original, named like
`settings.json.bak.20260610-153000`. Restart the affected applications
(Claude Code / VS Code / your terminal) after installing.

### Updating

```bash
git pull
./install.sh <module>
```

The claude module also ships `ccnotify`, which checks, upgrades, and rolls
back by GitHub release — see [claude/README.md](claude/README.md).

### Exporting local changes back into the repo

The vscode and starship modules provide export scripts:

```bash
bash vscode/export.sh
bash starship/export.sh
```

Review the exported files for secrets (tokens, proxy addresses, private
hosts) before committing.

### Testing

```bash
bash scripts/test.sh
```

All tests run offline against temporary directories and never touch your
real configuration.
````

- [ ] **Step 3: Create `vscode/README.md`**

````markdown
# vscode — VS Code settings, keybindings, and extensions

[中文](#中文) | [English](#english)

## 中文

### 用途

同步 VS Code 的 `settings.json`、`keybindings.json` 和插件清单
`extensions.txt`。

### 前置条件

- macOS
- VS Code 已安装（<https://code.visualstudio.com/>）
- 安装/导出插件需要 `code` 命令行工具：在 VS Code 中打开命令面板
  （Cmd+Shift+P），运行 "Shell Command: Install 'code' command in PATH"。
  没有 `code` CLI 时，settings 和 keybindings 仍会正常复制，只是跳过插件
  安装并给出提示。

### 安装内容

```text
~/Library/Application Support/Code/User/settings.json
~/Library/Application Support/Code/User/keybindings.json
```

外加 `extensions.txt` 中列出的全部插件（每行一个插件 id）。

### 安装

```bash
./install.sh vscode        # 从仓库根目录
# 或
bash vscode/install.sh     # 直接运行模块脚本
```

覆盖前自动生成 `.bak.YYYYMMDD-HHMMSS` 备份。单个插件安装失败不会中断，
结束时汇总报告。安装后重启 VS Code。

### 导出本机改动

```bash
bash vscode/export.sh
```

把本机的 settings、keybindings 复制回仓库，并用 `code --list-extensions`
重新生成 `extensions.txt`。提交前请检查 settings.json 中是否有密钥、代理
等私密内容。

### 恢复或卸载

把对应的 `.bak.*` 备份复制回原文件名即可恢复。本模块不会删除任何插件。

### 排障

- 提示 skipped installing extensions：`code` CLI 不在 PATH，按上面"前置
  条件"启用后重跑。
- 某个插件安装失败：检查插件 id 是否还在应用市场存在，或网络是否可达。

## English

### What it does

Syncs VS Code's `settings.json`, `keybindings.json`, and the extension list
`extensions.txt`.

### Prerequisites

- macOS
- VS Code installed (<https://code.visualstudio.com/>)
- The `code` CLI is required for extension install/export: open the Command
  Palette (Cmd+Shift+P) in VS Code and run "Shell Command: Install 'code'
  command in PATH". Without the CLI, settings and keybindings still copy
  fine; extension installation is skipped with a note.

### Installed Files

```text
~/Library/Application Support/Code/User/settings.json
~/Library/Application Support/Code/User/keybindings.json
```

Plus every extension listed in `extensions.txt` (one id per line).

### Install

```bash
./install.sh vscode        # from the repo root
# or
bash vscode/install.sh     # run the module script directly
```

Existing files are backed up as `.bak.YYYYMMDD-HHMMSS` first. A failing
extension does not abort the install; failures are summarized at the end.
Restart VS Code afterwards.

### Export local changes

```bash
bash vscode/export.sh
```

Copies your live settings and keybindings back into the repo and regenerates
`extensions.txt` via `code --list-extensions`. Review settings.json for
secrets (tokens, proxies, private hosts) before committing.

### Restore or Uninstall

Copy the matching `.bak.*` file back over the original to restore. This
module never uninstalls extensions.

### Troubleshooting

- "skipped installing extensions": the `code` CLI is not on PATH; enable it
  per Prerequisites and rerun.
- A specific extension fails to install: check that the id still exists on
  the marketplace and that the network is reachable.
````

- [ ] **Step 4: Create `starship/README.md`**

Adjust the Nerd Font line based on Task 6's glyph report: if the seeded
config uses glyphs, keep the Nerd Font bullet as written; if not, soften it
to "可选 / optional".

````markdown
# starship — Starship prompt configuration

[中文](#中文) | [English](#english)

## 中文

### 用途

同步 Starship 终端提示符的配置文件 `starship.toml`。

### 前置条件

- macOS
- starship 已安装：`brew install starship`
- 在 `~/.zshrc` 中启用：`eval "$(starship init zsh)"`（其他 shell 见
  <https://starship.rs/guide/>）
- 终端使用 Nerd Font 字体以正确显示图标（如 `brew install --cask
  font-jetbrains-mono-nerd-font`，然后在终端设置中选择该字体）

没有安装 starship 时，配置文件仍会复制，脚本会打印上述安装提示。

### 安装内容

```text
~/.config/starship.toml
```

### 安装

```bash
./install.sh starship      # 从仓库根目录
# 或
bash starship/install.sh
```

覆盖前自动生成 `.bak.YYYYMMDD-HHMMSS` 备份。新开终端窗口生效。

### 导出本机改动

```bash
bash starship/export.sh
```

### 恢复或卸载

恢复：把 `.bak.*` 备份复制回 `~/.config/starship.toml`。
卸载：删除该文件并从 `~/.zshrc` 移除 starship 初始化行。

### 排障

- 提示符没变化：确认 `~/.zshrc` 里有 `eval "$(starship init zsh)"` 并新开
  终端。
- 图标显示为方块：终端字体不是 Nerd Font，按前置条件安装并切换字体。

## English

### What it does

Syncs the Starship prompt configuration file `starship.toml`.

### Prerequisites

- macOS
- starship installed: `brew install starship`
- Enabled in `~/.zshrc`: `eval "$(starship init zsh)"` (other shells: see
  <https://starship.rs/guide/>)
- A Nerd Font in your terminal so glyphs render (e.g. `brew install --cask
  font-jetbrains-mono-nerd-font`, then select it in your terminal settings)

If starship is not installed, the config still copies and the script prints
the setup hints above.

### Installed Files

```text
~/.config/starship.toml
```

### Install

```bash
./install.sh starship      # from the repo root
# or
bash starship/install.sh
```

The existing file is backed up as `.bak.YYYYMMDD-HHMMSS` first. Open a new
terminal window to see the change.

### Export local changes

```bash
bash starship/export.sh
```

### Restore or Uninstall

Restore: copy the `.bak.*` backup back to `~/.config/starship.toml`.
Uninstall: delete that file and remove the starship init line from
`~/.zshrc`.

### Troubleshooting

- Prompt unchanged: confirm `eval "$(starship init zsh)"` is in `~/.zshrc`
  and open a new terminal.
- Icons render as boxes: your terminal font is not a Nerd Font; install and
  select one per Prerequisites.
````

- [ ] **Step 5: Sanity checks and commit**

```bash
bash scripts/test.sh
grep -c '^```' README.md claude/README.md vscode/README.md starship/README.md
```

Expected: suite green; every fence count even. Verify each README has both
`## 中文` and `## English`, and the root README's module links resolve
(`ls claude/README.md vscode/README.md starship/README.md`).

```bash
git add README.md claude/README.md vscode/README.md starship/README.md
git commit -m "Restructure documentation around modules"
```

---

### Task 8: Final verification and directory rename

- [ ] **Step 1: Full suite + smoke checks**

```bash
bash scripts/test.sh
bash install.sh                        # usage, exit 0
bash install.sh bogus || echo "(failed as expected)"
bash claude/bin/ccnotify help | head -5
git log --oneline -12
git status --short
```

Expected: suite green; usage printed; bogus rejected; ccnotify usage intact; one purpose per commit; clean tree.

- [ ] **Step 2: Rename the working directory (FINAL step — breaks open shells)**

This must be the very last action. Run from OUTSIDE the repo using absolute paths; afterwards every command must use the new path.

```bash
mv /Users/index/project/claude-code-macos-notify-statusline /Users/index/project/dotfiles
git -C /Users/index/project/dotfiles status --short
git -C /Users/index/project/dotfiles log --oneline -1
bash /Users/index/project/dotfiles/scripts/test.sh
```

Expected: git works from the new path; suite green. Note: the rename invalidates the current shell's cwd and any open editors — the controller/user should be told to reopen from `/Users/index/project/dotfiles`.

---

## Out of Scope (deliberate)

- GitHub repo creation, pushing, replacing `OWNER/REPO` in `claude/bin/ccnotify` and the READMEs' clone URLs, and the first release tag — all publish-time work.
- zsh / brew / terminal-emulator modules — future specs.
- Uninstall automation — docs describe manual steps only.
