#!/usr/bin/env bash
set -euo pipefail

input="$(cat || true)"

/usr/bin/python3 - "$input" <<'PY'
import json
import os
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

title = f"[Claude] {project}"

script = """
on run argv
  display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name (item 4 of argv)
end run
"""

subprocess.run(["/usr/bin/osascript", "-e", script, body, title, subtitle, sound], check=False)
PY
