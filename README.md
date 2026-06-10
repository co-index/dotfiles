# Claude Code macOS notifications and status line

Reusable Claude Code setup for:

- macOS notifications when Claude Code stops or needs attention.
- A compact multi-line status line powered by `ccstatusline`.
- A safe install script that backs up existing files before writing.

You can add a screenshot like the one in your terminal to `docs/statusline-preview.png`
before publishing.

## What this installs

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
```

It also merges these Claude Code settings:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/ccstatusline-usage-api.sh",
    "padding": 0
  },
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify-macos.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify-macos.sh"
          }
        ]
      }
    ]
  }
}
```

## Requirements

- macOS
- Claude Code
- Python 3 at `/usr/bin/python3`
- Node.js/npm, because the status line wrapper runs `npx -y ccstatusline@latest`

## Install

```bash
git clone https://github.com/YOUR_NAME/claude-code-macos-notify-statusline.git
cd claude-code-macos-notify-statusline
./install.sh
```

Restart Claude Code after installation.

## Manual install

```bash
mkdir -p ~/.claude/hooks ~/.config/ccstatusline
cp scripts/notify-macos.sh ~/.claude/hooks/notify-macos.sh
cp scripts/ccstatusline-usage-api.sh ~/.claude/ccstatusline-usage-api.sh
cp config/ccstatusline-settings.json ~/.config/ccstatusline/settings.json
chmod +x ~/.claude/hooks/notify-macos.sh ~/.claude/ccstatusline-usage-api.sh
```

Then merge `config/claude-settings.example.json` into `~/.claude/settings.json`.

## Safety notes

Do not publish your real Claude Code state files. In particular, never commit:

- `~/.claude/.credentials.json`
- `~/.claude.json`
- `~/.claude/sessions/`
- `~/.claude/projects/`
- `~/.claude/daemon*`
- `~/.claude/cache/`
- `~/.claude/telemetry/`

This repository keeps only reusable scripts and sanitized examples.

## Customize

- Edit `config/ccstatusline-settings.json` to change layout, colors, or usage rows.
- Edit `scripts/notify-macos.sh` to change notification text or macOS sound names.
- Edit `scripts/ccstatusline-usage-api.sh` if your status line input format changes.
