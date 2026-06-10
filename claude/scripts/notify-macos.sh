#!/usr/bin/env bash
set -euo pipefail

input="$(cat || true)"

/usr/bin/python3 - "$input" <<'PY'
import json
import os
import shutil
import subprocess
import sys
from collections import deque

raw = sys.argv[1] if len(sys.argv) > 1 else ""

try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

event = data.get("hook_event_name") or data.get("event") or "Claude"
cwd = (
    data.get("cwd")
    or data.get("workspace")
    or data.get("workspace_dir")
    or data.get("project_dir")
    or os.getcwd()
)
session_id = data.get("session_id") or data.get("sessionId") or ""
transcript_path = data.get("transcript_path") or data.get("transcriptPath") or ""
message = (
    data.get("message")
    or data.get("notification")
    or data.get("reason")
    or data.get("stop_reason")
    or ""
)


def normalize_text(value):
    if not value:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts = []
        for item in value:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict):
                text = item.get("text") or item.get("content")
                if isinstance(text, str):
                    parts.append(text)
        return " ".join(parts)
    if isinstance(value, dict):
        return normalize_text(value.get("text") or value.get("content"))
    return str(value)


def compact(text, limit=46):
    text = " ".join(str(text).replace("\n", " ").split())
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def extract_task_from_transcript(path):
    if not path or not os.path.isfile(path):
        return ""
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as file:
            recent = deque(file, maxlen=200)
    except Exception:
        return ""

    for line in reversed(recent):
        try:
            item = json.loads(line)
        except Exception:
            continue

        role = item.get("role")
        msg = item.get("message")
        if isinstance(msg, dict):
            role = role or msg.get("role")

        if role != "user" and item.get("type") != "user":
            continue

        content = item.get("content")
        if isinstance(msg, dict):
            content = msg.get("content", content)

        text = normalize_text(content)
        if not text:
            continue
        if text.startswith("<") and ">" in text[:80]:
            continue
        return compact(text)

    return ""


project = os.path.basename(os.path.abspath(cwd)) if cwd else ""
if not project and transcript_path:
    project = os.path.basename(os.path.dirname(transcript_path))
if not project:
    project = "Claude Code"

short_session = session_id[:8] if isinstance(session_id, str) and session_id else ""
task = (
    normalize_text(data.get("prompt"))
    or normalize_text(data.get("user_prompt"))
    or normalize_text(data.get("task"))
    or normalize_text(data.get("description"))
    or extract_task_from_transcript(transcript_path)
)
task = compact(task) if task else ""

if event == "Stop":
    body = "Task completed"
    sound = "Glass"
elif event == "Notification":
    body = "Claude needs your attention"
    sound = "Ping"
else:
    body = f"Event: {event}"
    sound = "Submarine"

if message:
    text = str(message).replace("\n", " ").strip()
    if text and text != task:
        body = f"{body} - {compact(text, 54)}"

subtitle_parts = []
if task:
    subtitle_parts.append(task)
elif project:
    subtitle_parts.append(project)
if short_session:
    subtitle_parts.append(f"session {short_session}")
subtitle = " | ".join(subtitle_parts)[:120]

# No leading "[": terminal-notifier drops -title values that start with it.
title = f"Claude · {project}"


def activate_bundle_id():
    # The app to focus when the notification is clicked. Hooks inherit the
    # environment of the app Claude Code runs in, so TERM_PROGRAM identifies
    # it; CCNOTIFY_ACTIVATE_BUNDLE_ID overrides the mapping.
    override = os.environ.get("CCNOTIFY_ACTIVATE_BUNDLE_ID")
    if override:
        return override
    return {
        "vscode": "com.microsoft.VSCode",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "ghostty": "com.mitchellh.ghostty",
        "Hyper": "co.zeit.hyper",
    }.get(os.environ.get("TERM_PROGRAM", ""), "")


def find_ccnotify():
    # The ccnotify helper (https://github.com/co-index/ccnotify) posts
    # clickable notifications. Several unrelated tools are also named
    # "ccnotify", so only accept a shim that references the ccnotify.app
    # bundle the helper installs.
    candidates = [
        "/opt/homebrew/bin/ccnotify",
        "/usr/local/bin/ccnotify",
        shutil.which("ccnotify") or "",
    ]
    for path in candidates:
        if not path or not os.access(path, os.X_OK):
            continue
        try:
            with open(path, "rb") as fh:
                head = fh.read(4096)
        except Exception:
            continue
        if b"ccnotify.app" in head:
            return path
    return ""


# Prefer ccnotify (modern notification API, click jumps back to the app),
# then terminal-notifier, then the non-clickable osascript fallback.
notifier = find_ccnotify() or shutil.which("terminal-notifier") or next(
    (
        path
        for path in (
            "/opt/homebrew/bin/terminal-notifier",
            "/usr/local/bin/terminal-notifier",
        )
        if os.path.exists(path)
    ),
    "",
)

if notifier:
    # Clickable notification; -activate focuses the app that was running
    # Claude Code when the hook fired.
    cmd = [notifier, "-title", title, "-message", body, "-sound", sound]
    if subtitle:
        cmd += ["-subtitle", subtitle]
    bundle_id = activate_bundle_id()
    if bundle_id:
        cmd += ["-activate", bundle_id]
    subprocess.run(
        cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
else:
    # Fallback: native AppleScript notification (not clickable).
    script = """
on run argv
  display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name (item 4 of argv)
end run
"""
    subprocess.run(["/usr/bin/osascript", "-e", script, body, title, subtitle, sound], check=False)
PY
