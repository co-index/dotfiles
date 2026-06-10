#!/usr/bin/env bash
set -euo pipefail

input="$(cat || true)"

plan_label="$(/usr/bin/python3 -c 'import json, os
config_dir = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
account_path = os.path.join(os.path.dirname(config_dir), ".claude.json")
try:
    with open(account_path, "r", encoding="utf-8") as fh:
        account = json.load(fh)
    oauth = account.get("oauthAccount") or {}
    tier = oauth.get("organizationRateLimitTier") or oauth.get("userRateLimitTier") or ""
    if "claude_max" in tier:
        print("Claude Max " + tier.rsplit("_", 1)[-1].upper(), end="")
    elif oauth.get("organizationType") == "claude_max":
        print("Claude Max", end="")
except Exception:
    pass
')"

project_label="$(printf '%s' "$input" | /usr/bin/python3 -c 'import json, os, subprocess, sys

def first_string(*values):
    for value in values:
        if isinstance(value, str) and value.strip():
            return value
    return ""

def find_path(data):
    workspace = data.get("workspace") if isinstance(data.get("workspace"), dict) else {}
    return first_string(
        data.get("cwd"),
        data.get("current_dir"),
        data.get("project_dir"),
        workspace.get("current_dir"),
        workspace.get("project_dir"),
    )

def original_repo_from_claude_worktree(path):
    marker = f"{os.sep}.claude{os.sep}worktrees{os.sep}"
    if marker not in path:
        return ""
    return path.split(marker, 1)[0]

def git_root(path):
    try:
        return subprocess.check_output(
            ["git", "-C", path, "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=0.25,
        ).strip()
    except Exception:
        return ""

def display_name(path):
    path = os.path.abspath(os.path.expanduser(path))
    root = original_repo_from_claude_worktree(path) or git_root(path) or path
    return os.path.basename(root.rstrip(os.sep))

try:
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}
    path = find_path(data)
    if path:
        print(display_name(path), end="")
except Exception:
    pass
')"

worktree_label="$(printf '%s' "$input" | /usr/bin/python3 -c 'import json, os, subprocess, sys

def first_string(*values):
    for value in values:
        if isinstance(value, str) and value.strip():
            return value
    return ""

def find_path(data):
    workspace = data.get("workspace") if isinstance(data.get("workspace"), dict) else {}
    return first_string(
        data.get("cwd"),
        data.get("current_dir"),
        data.get("project_dir"),
        workspace.get("current_dir"),
        workspace.get("project_dir"),
    )

def claude_worktree_name(path):
    marker = f"{os.sep}.claude{os.sep}worktrees{os.sep}"
    if marker not in path:
        return ""
    suffix = path.split(marker, 1)[1]
    return suffix.split(os.sep, 1)[0]

def git_output(path, *args):
    try:
        return subprocess.check_output(
            ["git", "-C", path, *args],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=0.35,
        ).strip()
    except Exception:
        return ""

def git_worktree_name(path):
    git_dir = git_output(path, "rev-parse", "--git-dir")
    common_dir = git_output(path, "rev-parse", "--git-common-dir")
    if not git_dir or not common_dir:
        return ""

    git_dir_abs = os.path.abspath(os.path.join(path, git_dir)) if not os.path.isabs(git_dir) else git_dir
    common_abs = os.path.abspath(os.path.join(path, common_dir)) if not os.path.isabs(common_dir) else common_dir
    worktrees_dir = os.path.join(common_abs, "worktrees")
    if git_dir_abs.startswith(worktrees_dir + os.sep):
        return os.path.basename(git_dir_abs)
    return ""

try:
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}
    path = find_path(data)
    if path:
        path = os.path.abspath(os.path.expanduser(path))
        print(claude_worktree_name(path) or git_worktree_name(path) or "no", end="")
except Exception:
    pass
')"

printf '%s' "$input" | /usr/bin/python3 -c '
import json
import sys

raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    print(raw, end="")
    raise SystemExit(0)

print(json.dumps(data, ensure_ascii=False), end="")
' | npx -y ccstatusline@2.2.19 | CC_PLAN_LABEL="$plan_label" \
  CC_PROJECT_LABEL="$project_label" \
  CC_WORKTREE_LABEL="$worktree_label" \
  /usr/bin/python3 -c '
import os
import re
import sys

text = sys.stdin.read()
text = text.replace("__CLAUDE_PLAN__", os.environ.get("CC_PLAN_LABEL") or "Claude")
project = (os.environ.get("CC_PROJECT_LABEL") or "").strip()
worktree = (os.environ.get("CC_WORKTREE_LABEL") or "").strip()
green = "\033[38;5;70m"
empty_green = "\033[38;5;22m"
block = "█"

def make_bar(percent):
    total = 40
    used = max(0, min(total, round(percent / 100 * total)))
    return green + block * used + empty_green + block * (total - used) + green

def compact_bracketed(match):
    percent = float(match.group(2))
    return match.group(1) + make_bar(percent) + " " + match.group(2) + "%"

def compact_slider(match):
    percent_text = match.group(1)
    percent = float(percent_text)
    return make_bar(percent) + " " + percent_text + "%"

text = re.sub(r"(\[+[█░]+\]\s*)(\d+(?:\.\d+)?)%", compact_bracketed, text)
text = re.sub(r"[▓░]{10}\s+(\d+(?:\.\d+)?)%", compact_slider, text)
if project and "Proj:" not in text:
    lines = text.splitlines(keepends=True)
    if lines:
        newline = ""
        if lines[0].endswith("\r\n"):
            newline = "\r\n"
            lines[0] = lines[0][:-2]
        elif lines[0].endswith("\n"):
            newline = "\n"
            lines[0] = lines[0][:-1]
        lines[0] = f"{lines[0]} | Proj: {project}{newline}"
        text = "".join(lines)
if worktree and "WT:" not in text:
    lines = text.splitlines(keepends=True)
    if len(lines) >= 2:
        newline = ""
        if lines[1].endswith("\r\n"):
            newline = "\r\n"
            lines[1] = lines[1][:-2]
        elif lines[1].endswith("\n"):
            newline = "\n"
            lines[1] = lines[1][:-1]
        lines[1] = f"{lines[1]} | WT: {worktree}{newline}"
        text = "".join(lines)
print(text, end="")
'
