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
