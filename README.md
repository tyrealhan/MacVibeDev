# macOS Vibe Dev Setup

一个面向 macOS 的一键工作环境配置脚本。

脚本入口是 [setup-macos-dev.sh](./setup-macos-dev.sh)。它会按“先检查、后安装、再配置”的方式处理常用开发环境，并且可以重复执行。

## Quick Install

直接执行：

```bash
curl -fsSL https://raw.githubusercontent.com/tyrealhan/MacVibeDev/main/setup-macos-dev.sh | bash
```

执行完成后，重新打开一个终端窗口，或者手动加载配置：

```bash
source ~/.zprofile
source ~/.zshrc
```

## Features

- 安装并初始化 Homebrew
- 安装并初始化 zoxide
- 安装并初始化 Starship
- 安装并初始化 Ghostty
- 安装 JetBrainsMono Nerd Font
- 安装 Codex CLI
- 安装 Sublime Text、Fork、Visual Studio Code
- 使用 Claude 官方安装脚本安装 Claude Code，并写入代理设置
- 统一维护 `~/.zprofile` 和 `~/.zshrc`

## What It Configures

脚本会使用下面这些默认值：

```bash
PROXY_URL="http://127.0.0.1:7899"
STARSHIP_PRESET="catppuccin-powerline"
STARSHIP_PALETTE="catppuccin_mocha"
GHOSTTY_FONT="JetBrainsMono Nerd Font"
```

### Zsh

会维护两个文件：

- `~/.zprofile`
- `~/.zshrc`

`~/.zprofile` 中会写入一个受管 block，包含：

- Homebrew `shellenv`
- `http_proxy`
- `https_proxy`

`~/.zshrc` 中会写入一个受管 block，包含：

- `export PATH="$HOME/.local/bin:$PATH"`
- `eval "$(zoxide init zsh)"`
- 仅在非 Apple Terminal 下启用 Starship

脚本会先删除自己之前写入的 block，再清理少量重复的同类行，然后写入最新配置，避免重复初始化。

### Starship

会直接重建：

- `~/.config/starship.toml`

配置来源是 Starship 官方 preset：

- preset: `catppuccin-powerline`
- flavour: `catppuccin_mocha`

生成 preset 后，还会补上这个设置：

```toml
[line_break]
disabled = false
```

### Ghostty

只会写入这个文件：

- `~/.config/ghostty/config.ghostty`

会设置这些键：

```ini
font-family = JetBrainsMono Nerd Font
background-opacity = 0.90
background-blur = true
keybind = ctrl+`=toggle_quick_terminal
cursor-style = block
shell-integration-features = no-cursor
```

如果检测到 Ghostty 的旧配置路径，脚本只会提示，不会去改旧文件。

## Install Targets

脚本会按需安装这些组件：

- `Homebrew`
- `zoxide`
- `starship`
- `Ghostty`
- `font-jetbrains-mono-nerd-font`
- `codex`
- `sublime-text`
- `fork`
- `visual-studio-code`
- `Claude Code`（官方安装脚本）

安装策略是：

- 已安装：跳过安装，直接进入配置步骤
- 未安装：先安装，再配置

对于 GUI 应用，脚本会优先检查：

- `/Applications`
- `~/Applications`
- Spotlight 可见的应用索引

## Files That May Change

脚本只会修改以下文件：

- `~/.zprofile`
- `~/.zshrc`
- `~/.config/starship.toml`
- `~/.config/ghostty/config.ghostty`
- `~/.claude/settings.json`

不会创建备份文件，也不会改动其他无关配置文件。

## Requirements

- macOS
- `bash`
- `curl`
- `ruby`
- 网络可访问 Homebrew、GitHub、Claude 和相关下载源

## Idempotency

这个脚本设计为可重复执行：

- 不会重复安装已经存在的组件
- 已存在的 GUI 应用会跳过对应的 `brew install --cask`
- 不会在 `~/.zprofile` / `~/.zshrc` 中追加多份相同初始化内容
- Ghostty 和 Claude Code 配置会按目标键更新
- Starship 配置会每次重生为同一份 preset
- 已存在的 `codex` 命令会直接跳过安装
- 已存在的 `claude` 命令会直接跳过官方安装

## Notes

- `~/.config/starship.toml` 会被整文件重写，这是刻意行为。
- Ghostty 统一使用 `~/.config/ghostty/config.ghostty` 作为目标路径。
- Codex 只负责安装命令行工具，本脚本不会额外写入 Codex 配置文件。

## Final Step: Claude Code

脚本最后的 Claude 阶段会先更新：

- `~/.claude/settings.json`

只会确保以下代理环境变量存在：

```json
{
  "env": {
    "HTTP_PROXY": "http://127.0.0.1:7899",
    "HTTPS_PROXY": "http://127.0.0.1:7899"
  }
}
```

如果 `settings.json` 已经存在，脚本只会 merge `env.HTTP_PROXY` 和 `env.HTTPS_PROXY`，不会覆盖其他字段。

然后把 Claude Code 安装作为脚本最后一个安装步骤，执行：

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

安装结束后，脚本会确保 `~/.zshrc` 的受管 block 中存在：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

然后尝试在新的 `zsh` 进程中重新加载一次 `~/.zshrc`。

## References

- [Homebrew](https://brew.sh/)
- [zoxide README](https://github.com/ajeetdsouza/zoxide)
- [Starship Configuration](https://starship.rs/config/)
- [Starship Catppuccin Powerline](https://starship.rs/presets/catppuccin-powerline)
- [Ghostty Configuration](https://ghostty.org/docs/config)
- [Claude Code Setup](https://docs.claude.com/en/docs/claude-code/setup)
- [Claude Code Settings](https://docs.claude.com/en/docs/claude-code/settings)
- [Claude Code Corporate Proxy](https://code.claude.com/docs/en/corporate-proxy)
