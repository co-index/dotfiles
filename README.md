# Claude Code macOS notifications and status line

[中文](#中文) | [English](#english)

Reusable Claude Code setup for macOS desktop notifications and a compact
multi-line status line powered by `ccstatusline`.

## 中文

### 功能

- 当 Claude Code 停止运行或需要你关注时，发送 macOS 通知。
- 使用 `ccstatusline` 显示紧凑的多行状态栏。
- 在状态栏中补充项目名、worktree 名称和 Claude Max 计划标签。
- 安装脚本会在覆盖已有文件前自动备份。

### 安装内容

安装脚本会写入以下文件：

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
```

并把以下配置合并到 Claude Code 设置文件：

```text
~/.claude/settings.json
```

如果文件已经存在，安装脚本会生成同目录备份，格式类似：

```text
settings.json.bak.20260610-153000
```

### 系统要求

- macOS
- Claude Code
- `/usr/bin/python3`
- Node.js 和 npm，因为状态栏包装脚本会运行 `npx -y ccstatusline@latest`

### 自动安装

```bash
git clone https://github.com/YOUR_NAME/claude-code-macos-notify-statusline.git
cd claude-code-macos-notify-statusline
chmod +x install.sh
./install.sh
```

安装完成后，重启 Claude Code 让新配置生效。

如果你使用自定义 Claude Code 配置目录，可以设置 `CLAUDE_CONFIG_DIR`：

```bash
CLAUDE_CONFIG_DIR="$HOME/.claude" ./install.sh
```

### 手动安装

```bash
mkdir -p ~/.claude/hooks ~/.config/ccstatusline
cp scripts/notify-macos.sh ~/.claude/hooks/notify-macos.sh
cp scripts/ccstatusline-usage-api.sh ~/.claude/ccstatusline-usage-api.sh
cp config/ccstatusline-settings.json ~/.config/ccstatusline/settings.json
chmod +x ~/.claude/hooks/notify-macos.sh ~/.claude/ccstatusline-usage-api.sh
```

然后把 `config/claude-settings.example.json` 中的内容合并到：

```text
~/.claude/settings.json
```

### 配置说明

Claude Code 配置示例：

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

`Notification` 事件会提示 Claude 需要你关注，`Stop` 事件会提示当前任务已结束。

### 自定义

- 修改 `config/ccstatusline-settings.json` 可调整状态栏行、颜色和用量展示。
- 修改 `scripts/notify-macos.sh` 可调整通知标题、正文、声音和内容截断长度。
- 修改 `scripts/ccstatusline-usage-api.sh` 可调整项目名、worktree 和计划标签的展示逻辑。

修改后重新运行 `./install.sh`，或手动复制对应文件到安装位置。

### 测试

测试 macOS 通知脚本：

```bash
printf '{"hook_event_name":"Notification","cwd":"%s","message":"Test notification"}' "$PWD" \
  | scripts/notify-macos.sh
```

测试状态栏脚本：

```bash
printf '{"cwd":"%s"}' "$PWD" | scripts/ccstatusline-usage-api.sh
```

首次运行状态栏脚本时，`npx` 可能需要下载 `ccstatusline`，所以会慢一些。

### 恢复或卸载

如果安装后想恢复旧配置，请把 `.bak.YYYYMMDD-HHMMSS` 备份文件复制回原文件名。

卸载时可删除本项目安装的文件：

```bash
rm -f ~/.claude/hooks/notify-macos.sh
rm -f ~/.claude/ccstatusline-usage-api.sh
rm -f ~/.config/ccstatusline/settings.json
```

然后从 `~/.claude/settings.json` 中移除本项目添加的 `statusLine`、`Notification`
和 `Stop` 配置，或恢复安装前生成的备份。

### 安全说明

不要发布你的真实 Claude Code 状态文件，尤其不要提交：

- `~/.claude/.credentials.json`
- `~/.claude.json`
- `~/.claude/sessions/`
- `~/.claude/projects/`
- `~/.claude/daemon*`
- `~/.claude/cache/`
- `~/.claude/telemetry/`

本仓库只保留可复用脚本和脱敏配置示例。

### 排障

- 没有通知：检查 macOS 的通知权限，以及 Claude Code 是否允许发送通知。
- 状态栏没有显示：确认 `~/.claude/settings.json` 的 `statusLine.command` 指向可执行脚本。
- 提示找不到 `npx`：安装 Node.js/npm，或确认它们在 Claude Code 启动环境的 `PATH` 中。
- 配置 JSON 报错：恢复安装脚本生成的 `.bak.*` 备份，修复 JSON 后再重新安装。

## English

### Features

- Sends macOS notifications when Claude Code stops or needs attention.
- Shows a compact multi-line status line through `ccstatusline`.
- Adds project, worktree, and Claude Max plan labels to the status line.
- Backs up existing files before the installer overwrites them.

### Installed Files

The installer writes these files:

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
```

It also updates the Claude Code settings file:

```text
~/.claude/settings.json
```

Existing files are backed up next to the original file with names like:

```text
settings.json.bak.20260610-153000
```

### Requirements

- macOS
- Claude Code
- `/usr/bin/python3`
- Node.js and npm, because the status line wrapper runs
  `npx -y ccstatusline@latest`

### Automatic Install

```bash
git clone https://github.com/YOUR_NAME/claude-code-macos-notify-statusline.git
cd claude-code-macos-notify-statusline
chmod +x install.sh
./install.sh
```

Restart Claude Code after installation.

If you use a custom Claude Code config directory, set `CLAUDE_CONFIG_DIR`:

```bash
CLAUDE_CONFIG_DIR="$HOME/.claude" ./install.sh
```

### Manual Install

```bash
mkdir -p ~/.claude/hooks ~/.config/ccstatusline
cp scripts/notify-macos.sh ~/.claude/hooks/notify-macos.sh
cp scripts/ccstatusline-usage-api.sh ~/.claude/ccstatusline-usage-api.sh
cp config/ccstatusline-settings.json ~/.config/ccstatusline/settings.json
chmod +x ~/.claude/hooks/notify-macos.sh ~/.claude/ccstatusline-usage-api.sh
```

Then merge `config/claude-settings.example.json` into:

```text
~/.claude/settings.json
```

### Configuration

Claude Code settings example:

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

`Notification` means Claude needs attention. `Stop` means the current task has
finished.

### Customization

- Edit `config/ccstatusline-settings.json` to change status line rows, colors,
  and usage display.
- Edit `scripts/notify-macos.sh` to change notification titles, body text,
  sounds, and truncation length.
- Edit `scripts/ccstatusline-usage-api.sh` to change how project, worktree, and
  plan labels are displayed.

After changing a file, run `./install.sh` again or copy the changed file into
the install location manually.

### Testing

Test the macOS notification hook:

```bash
printf '{"hook_event_name":"Notification","cwd":"%s","message":"Test notification"}' "$PWD" \
  | scripts/notify-macos.sh
```

Test the status line wrapper:

```bash
printf '{"cwd":"%s"}' "$PWD" | scripts/ccstatusline-usage-api.sh
```

The first status line run may be slower while `npx` downloads `ccstatusline`.

### Restore or Uninstall

To restore an older configuration, copy the matching `.bak.YYYYMMDD-HHMMSS`
file back to its original name.

To uninstall, remove the files installed by this project:

```bash
rm -f ~/.claude/hooks/notify-macos.sh
rm -f ~/.claude/ccstatusline-usage-api.sh
rm -f ~/.config/ccstatusline/settings.json
```

Then remove the added `statusLine`, `Notification`, and `Stop` settings from
`~/.claude/settings.json`, or restore the backup created before installation.

### Safety Notes

Do not publish your real Claude Code state files. In particular, never commit:

- `~/.claude/.credentials.json`
- `~/.claude.json`
- `~/.claude/sessions/`
- `~/.claude/projects/`
- `~/.claude/daemon*`
- `~/.claude/cache/`
- `~/.claude/telemetry/`

This repository keeps only reusable scripts and sanitized examples.

### Troubleshooting

- No notification appears: check macOS notification permissions and make sure
  Claude Code is allowed to send notifications.
- The status line does not appear: confirm that `statusLine.command` in
  `~/.claude/settings.json` points to an executable script.
- `npx` is not found: install Node.js/npm or make sure they are on the `PATH`
  available to Claude Code.
- Invalid settings JSON: restore the `.bak.*` file created by the installer,
  fix the JSON, and rerun the installer.
