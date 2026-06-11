# vscode — VS Code settings, keybindings, and extensions

[English](#english) | [中文](#中文)

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
- Cursor users beware: Cursor registers its own `code` shim. The scripts
  detect this — they prefer the CLI inside the VS Code app bundle and skip a
  `code` that resolves into Cursor.app, so extensions never land in Cursor by
  accident. Set `DOTFILES_CODE_BIN=/path/to/code` to force a specific CLI
  (for example, to target Cursor on purpose).

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

Note: `extensions.txt` is fully overwritten by the list of locally installed
extensions. Extensions that settings.json depends on (such as
`esbenp.prettier-vscode` or `usernamehw.errorlens`) are dropped from the
manifest if they are not installed locally — the script prints a diff, so
check it for accidental removals before committing.

### Restore or Uninstall

Restore: copy the matching `.bak.*` file back over the original.

Uninstall:

```bash
./uninstall.sh vscode        # from the repo root
# or
bash vscode/uninstall.sh     # run the module script directly
```

The script backs up and then removes settings.json and keybindings.json.
Manual removal also works:

```bash
rm -f "$HOME/Library/Application Support/Code/User/settings.json"
rm -f "$HOME/Library/Application Support/Code/User/keybindings.json"
```

This module never uninstalls extensions; remove unwanted ones manually in
VS Code.

### Troubleshooting

- "skipped installing extensions": the `code` CLI is not on PATH; enable it
  per Prerequisites and rerun.
- "belongs to Cursor": your `code` command points at Cursor and the VS Code
  bundle was not found in /Applications. Reinstall the shim from inside
  VS Code (Prerequisites above) or set `DOTFILES_CODE_BIN`.
- A specific extension fails to install: check that the id still exists on
  the marketplace and that the network is reachable (publishers occasionally
  rename — e.g. `typescript.native-preview` became
  `typescriptteam.native-preview`).


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
- Cursor 用户注意：Cursor 也会注册一个 `code` 命令。脚本已做识别——优先
  使用 VS Code 应用包内自带的 CLI，并跳过解析到 Cursor.app 的 `code`，
  插件不会被误装进 Cursor。如需强制指定 CLI（比如就是想装进 Cursor），
  设置 `DOTFILES_CODE_BIN=/path/to/code`。

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

注意：`extensions.txt` 会被本机已安装的插件列表完全覆盖。settings.json
依赖的插件（如 `esbenp.prettier-vscode`、`usernamehw.errorlens`）若本机
没有安装，导出会把它们从清单中移除——脚本会打印 diff，提交前请确认没有
误删。

### 恢复或卸载

恢复：把对应的 `.bak.*` 备份复制回原文件名即可。

卸载：

```bash
./uninstall.sh vscode        # 从仓库根目录
# 或
bash vscode/uninstall.sh     # 直接运行模块脚本
```

脚本会先备份再删除 settings.json 和 keybindings.json。也可以手动删除：

```bash
rm -f "$HOME/Library/Application Support/Code/User/settings.json"
rm -f "$HOME/Library/Application Support/Code/User/keybindings.json"
```

本模块不会删除任何插件；不需要的插件请在 VS Code 中手动卸载。

### 排障

- 提示 skipped installing extensions：`code` CLI 不在 PATH，按上面"前置
  条件"启用后重跑。
- 提示 belongs to Cursor：你的 `code` 命令指向 Cursor，且 /Applications
  里没有找到 VS Code。按"前置条件"在 VS Code 里重装 shim，或设置
  `DOTFILES_CODE_BIN`。
- 某个插件安装失败：检查插件 id 是否还在应用市场存在，或网络是否可达
  （发布者偶尔会改名，例如 `typescript.native-preview` 已改为
  `typescriptteam.native-preview`）。
