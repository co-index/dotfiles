# starship — Starship prompt configuration

[中文](#中文) | [English](#english)

## 中文

### 用途

同步 Starship 终端提示符的配置文件 `starship.toml`。

效果（starship 默认样式 + 单行提示符 + 无 Nerd Font 图标）：

![Starship 提示符](../docs/images/starship-prompt.png)

### 前置条件

- macOS
- starship 已安装：`brew install starship`
- 在 `~/.zshrc` 中启用：`eval "$(starship init zsh)"`（其他 shell 见
  <https://starship.rs/guide/>）
- 可选：终端使用 Nerd Font 字体（本配置只用标准 Unicode 符号，普通等宽字体即可正常显示；若你自行添加图标类模块则需要 Nerd Font，如 `brew install --cask font-jetbrains-mono-nerd-font`）

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

提交前请检查文件中是否有私有主机名等不宜公开的内容。

### 恢复或卸载

恢复：把 `.bak.*` 备份复制回 `~/.config/starship.toml`。

卸载：

```bash
./uninstall.sh starship        # 从仓库根目录
# 或
bash starship/uninstall.sh     # 直接运行模块脚本
```

脚本会先备份再删除 `~/.config/starship.toml`，等价于手动执行
`rm -f ~/.config/starship.toml`。

然后从 `~/.zshrc` 移除 `eval "$(starship init zsh)"` 这一行。

### 排障

- 提示符没变化：确认 `~/.zshrc` 里有 `eval "$(starship init zsh)"` 并新开
  终端。
- 图标显示为方块：只有在你自行添加了图标类模块时才会出现，安装并切换 Nerd Font 字体即可。

## English

### What it does

Syncs the Starship prompt configuration file `starship.toml`.

What it looks like (starship defaults + single-line prompt + no Nerd Font
icons):

![Starship prompt](../docs/images/starship-prompt.png)

### Prerequisites

- macOS
- starship installed: `brew install starship`
- Enabled in `~/.zshrc`: `eval "$(starship init zsh)"` (other shells: see
  <https://starship.rs/guide/>)
- Optional: a Nerd Font in your terminal (this config only uses standard Unicode symbols and renders fine in any monospace font; you only need a Nerd Font if you add glyph-heavy modules yourself, e.g. `brew install --cask font-jetbrains-mono-nerd-font`)

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

Check the file for private hostnames or anything else you would not publish
before committing.

### Restore or Uninstall

Restore: copy the `.bak.*` backup back to `~/.config/starship.toml`.

Uninstall:

```bash
./uninstall.sh starship        # from the repo root
# or
bash starship/uninstall.sh     # run the module script directly
```

The script backs up and then removes `~/.config/starship.toml`, equivalent
to running `rm -f ~/.config/starship.toml` by hand.

Then remove the `eval "$(starship init zsh)"` line from `~/.zshrc`.

### Troubleshooting

- Prompt unchanged: confirm `eval "$(starship init zsh)"` is in `~/.zshrc`
  and open a new terminal.
- Icons render as boxes: only happens if you added glyph-heavy modules; install and select a Nerd Font.
