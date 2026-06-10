# claude — Claude Code macOS notifications and status line

[中文](#中文) | [English](#english)

Claude Code 桌面通知、ccstatusline 状态栏与 ccnotify 版本管理。/ macOS
notifications, a ccstatusline-powered status line, and the ccnotify version
manager for Claude Code.

## 中文

### 功能

- 当 Claude Code 停止运行或需要你关注时，发送 macOS 通知。
- 使用 `ccstatusline` 显示紧凑的多行状态栏。
- 在状态栏中补充项目名、worktree 名称和 Claude Max 计划标签。
- 安装脚本会在覆盖已有文件前自动备份。
- 提供 `ccnotify` 命令，按 GitHub Release 版本检查、升级和回滚本套配置。

### 安装内容

安装脚本会写入以下文件：

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
~/.local/bin/ccnotify
~/.claude/ccnotify-state.json
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
- curl（macOS 自带，`ccnotify` 联网操作需要）
- Node.js 和 npm，因为状态栏包装脚本会运行 `npx -y ccstatusline@2.2.19`
  （版本已固定，避免每次渲染状态栏都联网解析 `@latest`；升级时改
  `claude/scripts/ccstatusline-usage-api.sh` 中的版本号）

### 自动安装

```bash
git clone https://github.com/co-index/dotfiles.git
cd dotfiles
./install.sh claude
```

安装完成后，重启 Claude Code 让新配置生效。

如果你使用自定义 Claude Code 配置目录，可以设置 `CLAUDE_CONFIG_DIR`：

```bash
CLAUDE_CONFIG_DIR="$HOME/.claude" ./install.sh claude
```

### 手动安装

```bash
mkdir -p ~/.claude/hooks ~/.config/ccstatusline ~/.local/bin
cp claude/scripts/notify-macos.sh ~/.claude/hooks/notify-macos.sh
cp claude/scripts/ccstatusline-usage-api.sh ~/.claude/ccstatusline-usage-api.sh
cp claude/config/ccstatusline-settings.json ~/.config/ccstatusline/settings.json
cp claude/bin/ccnotify ~/.local/bin/ccnotify
chmod +x ~/.claude/hooks/notify-macos.sh ~/.claude/ccstatusline-usage-api.sh \
  ~/.local/bin/ccnotify
```

然后把 `claude/config/claude-settings.example.json` 中的内容合并到：

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

### 更新与回滚

安装脚本会把 `ccnotify` 命令安装到 `~/.local/bin/ccnotify`，用于按 GitHub
Release 版本管理本套配置。所有安装操作都需要显式执行，`check` 只查询，
永远不会自动安装：

```bash
ccnotify check            # 检查最新版本，只查询不安装
ccnotify upgrade          # 升级到最新版本
ccnotify upgrade v1.2.0   # 安装指定版本
ccnotify rollback v1.1.0  # 回滚到指定旧版本
ccnotify version          # 查看当前安装的版本和路径
```

升级和回滚都会下载对应版本的源码包，并运行那个版本自带的 `install.sh`，
所以同样会先备份再覆盖。

如果 `~/.local/bin` 不在 `PATH` 中，安装脚本会提示你在 shell 配置里加入：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 自定义

- 修改 `claude/config/ccstatusline-settings.json` 可调整状态栏行、颜色和用量展示。
- 修改 `claude/scripts/notify-macos.sh` 可调整通知标题、正文、声音和内容截断长度。
- 修改 `claude/scripts/ccstatusline-usage-api.sh` 可调整项目名、worktree 和计划标签的展示逻辑。

修改后重新运行 `./install.sh claude`，或手动复制对应文件到安装位置。

### 测试

运行离线测试套件（语法检查、配置校验和临时目录安装测试）：

```bash
bash scripts/test.sh
```

测试 macOS 通知脚本：

```bash
printf '{"hook_event_name":"Notification","cwd":"%s","message":"Test notification"}' "$PWD" \
  | claude/scripts/notify-macos.sh
```

测试状态栏脚本：

```bash
printf '{"cwd":"%s"}' "$PWD" | claude/scripts/ccstatusline-usage-api.sh
```

首次运行状态栏脚本时，`npx` 可能需要下载 `ccstatusline`，所以会慢一些。

### 恢复或卸载

如果安装后想恢复旧配置，请把 `.bak.YYYYMMDD-HHMMSS` 备份文件复制回原文件名。

卸载时可删除本项目安装的文件：

```bash
rm -f ~/.claude/hooks/notify-macos.sh
rm -f ~/.claude/ccstatusline-usage-api.sh
rm -f ~/.config/ccstatusline/settings.json
rm -f ~/.local/bin/ccnotify
rm -f ~/.claude/ccnotify-state.json
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
- 找不到 `ccnotify` 命令：确认 `~/.local/bin` 在 `PATH` 中，或重新运行 `./install.sh`。
- `ccnotify check` 或 `upgrade` 失败：确认网络可以访问 GitHub，且 `claude/bin/ccnotify`
  中的 `GITHUB_REPO` 不再是 `OWNER/REPO` 占位符。

## English

### Features

- Sends macOS notifications when Claude Code stops or needs attention.
- Shows a compact multi-line status line through `ccstatusline`.
- Adds project, worktree, and Claude Max plan labels to the status line.
- Backs up existing files before the installer overwrites them.
- Ships a `ccnotify` command to check, upgrade, and roll back this setup by
  GitHub release version.

### Installed Files

The installer writes these files:

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
~/.local/bin/ccnotify
~/.claude/ccnotify-state.json
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
- curl (bundled with macOS; `ccnotify` needs it for network operations)
- Node.js and npm, because the status line wrapper runs
  `npx -y ccstatusline@2.2.19` (the version is pinned so the status line never
  resolves `@latest` over the network on every render; bump the version in
  `claude/scripts/ccstatusline-usage-api.sh` to upgrade)

### Automatic Install

```bash
git clone https://github.com/co-index/dotfiles.git
cd dotfiles
./install.sh claude
```

Restart Claude Code after installation.

If you use a custom Claude Code config directory, set `CLAUDE_CONFIG_DIR`:

```bash
CLAUDE_CONFIG_DIR="$HOME/.claude" ./install.sh claude
```

### Manual Install

```bash
mkdir -p ~/.claude/hooks ~/.config/ccstatusline ~/.local/bin
cp claude/scripts/notify-macos.sh ~/.claude/hooks/notify-macos.sh
cp claude/scripts/ccstatusline-usage-api.sh ~/.claude/ccstatusline-usage-api.sh
cp claude/config/ccstatusline-settings.json ~/.config/ccstatusline/settings.json
cp claude/bin/ccnotify ~/.local/bin/ccnotify
chmod +x ~/.claude/hooks/notify-macos.sh ~/.claude/ccstatusline-usage-api.sh \
  ~/.local/bin/ccnotify
```

Then merge `claude/config/claude-settings.example.json` into:

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

### Update and Rollback

The installer also installs a `ccnotify` command to `~/.local/bin/ccnotify`
that manages this setup by GitHub release version. Every install is explicit;
`check` only reports and never installs anything:

```bash
ccnotify check            # check the latest version, report only
ccnotify upgrade          # install the latest version
ccnotify upgrade v1.2.0   # install a specific version
ccnotify rollback v1.1.0  # roll back to an older version
ccnotify version          # show the installed version and paths
```

Upgrades and rollbacks download the source archive for the requested version
and run that version's own `install.sh`, so the usual backups still apply.

If `~/.local/bin` is not on your `PATH`, the installer prints a snippet to add
to your shell profile:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Customization

- Edit `claude/config/ccstatusline-settings.json` to change status line rows, colors,
  and usage display.
- Edit `claude/scripts/notify-macos.sh` to change notification titles, body text,
  sounds, and truncation length.
- Edit `claude/scripts/ccstatusline-usage-api.sh` to change how project, worktree, and
  plan labels are displayed.

After changing a file, run `./install.sh claude` again or copy the changed file into
the install location manually.

### Testing

Run the offline test suite (syntax checks, config validation, and a
temporary-directory install test):

```bash
bash scripts/test.sh
```

Test the macOS notification hook:

```bash
printf '{"hook_event_name":"Notification","cwd":"%s","message":"Test notification"}' "$PWD" \
  | claude/scripts/notify-macos.sh
```

Test the status line wrapper:

```bash
printf '{"cwd":"%s"}' "$PWD" | claude/scripts/ccstatusline-usage-api.sh
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
rm -f ~/.local/bin/ccnotify
rm -f ~/.claude/ccnotify-state.json
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
- `ccnotify` command not found: make sure `~/.local/bin` is on your `PATH`, or
  rerun `./install.sh`.
- `ccnotify check` or `upgrade` fails: make sure GitHub is reachable and
  `GITHUB_REPO` in `claude/bin/ccnotify` is no longer the `OWNER/REPO` placeholder.
