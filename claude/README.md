# claude — Claude Code macOS notifications and status line

[中文](#中文) | [English](#english)

Claude Code 桌面通知、ccstatusline 状态栏与 ccdots 版本管理。/ macOS
notifications, a ccstatusline-powered status line, and the ccdots version
manager for Claude Code.

## 中文

### 功能

- 当 Claude Code 停止运行或需要你关注时，发送 macOS 通知。
- 通知通过独立开源的 [ccnotify](https://github.com/co-index/ccnotify)
  发出（`brew install co-index/tap/ccnotify`）：点击横幅可跳回运行
  Claude Code 的应用（VS Code / Warp / Terminal / iTerm2 等，按
  `TERM_PROGRAM` 识别）。未安装时回退为 osascript 原生通知（不可点击）。
- 使用 `ccstatusline` 显示紧凑的多行状态栏。
- 在状态栏中补充项目名、worktree 名称和 Claude Max 计划标签。
- 安装脚本会在覆盖已有文件前自动备份。
- 提供 `ccdots` 命令，按 GitHub Release 版本检查、升级和回滚本套配置。

状态栏效果（模型/上下文/项目、计划/分支/worktree、5h 与 7d 用量条）：

![Claude Code 状态栏](../docs/images/claude-statusline.png)

通知效果：

![macOS 通知](../docs/images/claude-notification.png)

### 安装内容

安装脚本会写入以下文件：

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
~/.local/bin/ccdots
~/.claude/ccdots-state.json
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
- curl（macOS 自带，`ccdots` 联网操作需要）
- Node.js 和 npm，因为状态栏包装脚本会运行 `npx -y ccstatusline@2.2.19`
  （版本已固定，避免每次渲染状态栏都联网解析 `@latest`；升级时改
  `claude/scripts/ccstatusline-usage-api.sh` 中的版本号）
- 可选：[ccnotify](https://github.com/co-index/ccnotify)
  （`brew install co-index/tap/ccnotify`）——可点击通知；缺少时通知回退为
  osascript 原生样式（不可点击）

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
cp claude/bin/ccdots ~/.local/bin/ccdots
chmod +x ~/.claude/hooks/notify-macos.sh ~/.claude/ccstatusline-usage-api.sh \
  ~/.local/bin/ccdots
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

安装脚本会把 `ccdots` 命令安装到 `~/.local/bin/ccdots`，用于按 GitHub
Release 版本管理本套配置。所有安装操作都需要显式执行，`check` 只查询，
永远不会自动安装：

```bash
ccdots check            # 检查最新版本，只查询不安装
ccdots upgrade          # 升级到最新版本
ccdots upgrade v1.2.0   # 安装指定版本
ccdots rollback v1.1.0  # 回滚到指定旧版本
ccdots version          # 查看当前安装的版本和路径
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
- 通知点击跳转的应用按 `TERM_PROGRAM` 自动识别，未覆盖的终端可设
  `CCNOTIFY_ACTIVATE_BUNDLE_ID` 指定 bundle id。
- 通知器本体是独立项目
  [co-index/ccnotify](https://github.com/co-index/ccnotify)，想改图标或
  行为请去那个仓库。

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

卸载：

```bash
./uninstall.sh claude        # 从仓库根目录
# 或
bash claude/uninstall.sh     # 直接运行模块脚本
```

脚本会删除上面"安装内容"列出的全部文件（删除前先备份），并从
`~/.claude/settings.json` 中移除本项目添加的 `statusLine`、`Notification`
和 `Stop` 配置——你自己添加的设置和 hooks 会原样保留。

也可以手动卸载：

```bash
rm -f ~/.claude/hooks/notify-macos.sh
rm -f ~/.claude/ccstatusline-usage-api.sh
rm -f ~/.config/ccstatusline/settings.json
rm -f ~/.local/bin/ccdots
rm -f ~/.claude/ccdots-state.json
```

然后从 `~/.claude/settings.json` 中移除本项目添加的配置，或恢复安装前
生成的备份。brew 安装的 ccnotify 通知器是独立软件，需要时用
`brew uninstall ccnotify` 单独卸载。

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

本项目与 Anthropic 无关联；"Claude" 是 Anthropic, PBC 的商标，本仓库仅
用其指代 Claude Code 产品本身。通知器
[ccnotify](https://github.com/co-index/ccnotify) 为独立实现，设计思路致谢
[terminal-notifier](https://github.com/julienXX/terminal-notifier)。

### 排障

- 没有通知：通知器第一次发通知时会请求权限，去 系统设置 → 通知 里允许
  "ccnotify"；同时确认 Claude Code 本身允许发送通知。
- 通知不可点击：说明 ccnotify 未安装，运行
  `brew install co-index/tap/ccnotify`。
- 状态栏没有显示：确认 `~/.claude/settings.json` 的 `statusLine.command` 指向可执行脚本。
- 提示找不到 `npx`：安装 Node.js/npm，或确认它们在 Claude Code 启动环境的 `PATH` 中。
- 配置 JSON 报错：恢复安装脚本生成的 `.bak.*` 备份，修复 JSON 后再重新安装。
- 找不到 `ccdots` 命令：确认 `~/.local/bin` 在 `PATH` 中，或重新运行 `./install.sh`。
- `ccdots check` 或 `upgrade` 失败：确认网络可以访问 GitHub，且 `claude/bin/ccdots`
  中的 `GITHUB_REPO` 不再是 `OWNER/REPO` 占位符。

## English

### Features

- Sends macOS notifications when Claude Code stops or needs attention.
- Notifications go through the standalone open-source
  [ccnotify](https://github.com/co-index/ccnotify) helper
  (`brew install co-index/tap/ccnotify`): clicking a banner jumps back to
  the app running Claude Code (VS Code / Warp / Terminal / iTerm2 and
  friends, detected via `TERM_PROGRAM`). Without it, notifications fall
  back to the native osascript style (not clickable).
- Shows a compact multi-line status line through `ccstatusline`.
- Adds project, worktree, and Claude Max plan labels to the status line.
- Backs up existing files before the installer overwrites them.
- Ships a `ccdots` command to check, upgrade, and roll back this setup by
  GitHub release version.

The status line (model/context/project, plan/branch/worktree, and the 5h
and 7d usage bars):

![Claude Code status line](../docs/images/claude-statusline.png)

Notifications:

![macOS notification](../docs/images/claude-notification.png)

### Installed Files

The installer writes these files:

```text
~/.claude/hooks/notify-macos.sh
~/.claude/ccstatusline-usage-api.sh
~/.config/ccstatusline/settings.json
~/.local/bin/ccdots
~/.claude/ccdots-state.json
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
- curl (bundled with macOS; `ccdots` needs it for network operations)
- Node.js and npm, because the status line wrapper runs
  `npx -y ccstatusline@2.2.19` (the version is pinned so the status line never
  resolves `@latest` over the network on every render; bump the version in
  `claude/scripts/ccstatusline-usage-api.sh` to upgrade)
- Optional: [ccnotify](https://github.com/co-index/ccnotify)
  (`brew install co-index/tap/ccnotify`) for clickable notifications;
  without it notifications fall back to the native osascript style
  (not clickable)

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
cp claude/bin/ccdots ~/.local/bin/ccdots
chmod +x ~/.claude/hooks/notify-macos.sh ~/.claude/ccstatusline-usage-api.sh \
  ~/.local/bin/ccdots
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

The installer also installs a `ccdots` command to `~/.local/bin/ccdots`
that manages this setup by GitHub release version. Every install is explicit;
`check` only reports and never installs anything:

```bash
ccdots check            # check the latest version, report only
ccdots upgrade          # install the latest version
ccdots upgrade v1.2.0   # install a specific version
ccdots rollback v1.1.0  # roll back to an older version
ccdots version          # show the installed version and paths
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
- The app a clicked notification activates is detected via `TERM_PROGRAM`;
  set `CCNOTIFY_ACTIVATE_BUNDLE_ID` for terminals the mapping does not cover.
- The notifier itself is the standalone
  [co-index/ccnotify](https://github.com/co-index/ccnotify) project; change
  its icon or behavior over there.

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

To uninstall:

```bash
./uninstall.sh claude        # from the repo root
# or
bash claude/uninstall.sh     # run the module script directly
```

The script removes every file listed under Installed Files (backing each one
up first) and strips the `statusLine`, `Notification`, and `Stop` settings
this project added from `~/.claude/settings.json` — your own settings and
hooks are left untouched.

Manual uninstall is also possible:

```bash
rm -f ~/.claude/hooks/notify-macos.sh
rm -f ~/.claude/ccstatusline-usage-api.sh
rm -f ~/.config/ccstatusline/settings.json
rm -f ~/.local/bin/ccdots
rm -f ~/.claude/ccdots-state.json
```

Then remove the added settings from `~/.claude/settings.json`, or restore the
backup created before installation. The brew-installed ccnotify notifier is
separate software; remove it with `brew uninstall ccnotify` if you want it
gone too.

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

This project is not affiliated with Anthropic; "Claude" is a trademark of
Anthropic, PBC and is used here only to refer to the Claude Code product.
The [ccnotify](https://github.com/co-index/ccnotify) notifier is an
independent implementation whose design tips its hat to
[terminal-notifier](https://github.com/julienXX/terminal-notifier).

### Troubleshooting

- No notification appears: the notifier asks for permission the first time
  it posts — allow "ccnotify" under System Settings -> Notifications, and
  make sure Claude Code itself is allowed to send notifications.
- Notifications are not clickable: the ccnotify helper is missing — run
  `brew install co-index/tap/ccnotify`.
- The status line does not appear: confirm that `statusLine.command` in
  `~/.claude/settings.json` points to an executable script.
- `npx` is not found: install Node.js/npm or make sure they are on the `PATH`
  available to Claude Code.
- Invalid settings JSON: restore the `.bak.*` file created by the installer,
  fix the JSON, and rerun the installer.
- `ccdots` command not found: make sure `~/.local/bin` is on your `PATH`, or
  rerun `./install.sh`.
- `ccdots check` or `upgrade` fails: make sure GitHub is reachable and
  `GITHUB_REPO` in `claude/bin/ccdots` is no longer the `OWNER/REPO` placeholder.
