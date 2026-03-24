#!/usr/bin/env bash

set -euo pipefail

PROXY_URL="http://127.0.0.1:7899"
STARSHIP_PRESET="catppuccin-powerline"
STARSHIP_PALETTE="catppuccin_mocha"
GHOSTTY_FONT="JetBrainsMono Nerd Font"

SCRIPT_TAG="macos-dev-setup"
MANAGED_START="# >>> ${SCRIPT_TAG} >>>"
MANAGED_END="# <<< ${SCRIPT_TAG} <<<"

BREW_BIN=""
WARNINGS_FILE=""

log() {
  printf '[INFO] %s\n' "$1"
}

success() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
  if [ -n "${WARNINGS_FILE}" ]; then
    printf '%s\n' "$1" >> "$WARNINGS_FILE"
  fi
}

die() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    die "This script only supports macOS."
  fi
}

require_prerequisites() {
  command -v curl >/dev/null 2>&1 || die "curl is required."
  command -v ruby >/dev/null 2>&1 || die "ruby is required."
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

find_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi
  if [ -x /opt/homebrew/bin/brew ]; then
    printf '/opt/homebrew/bin/brew\n'
    return 0
  fi
  if [ -x /usr/local/bin/brew ]; then
    printf '/usr/local/bin/brew\n'
    return 0
  fi
  return 1
}

ensure_homebrew() {
  if BREW_BIN="$(find_brew_bin 2>/dev/null)"; then
    log "Homebrew already installed at ${BREW_BIN}"
  else
    log "Installing Homebrew from the official installer"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    BREW_BIN="$(find_brew_bin)" || die "Homebrew installation finished but brew was not found."
    success "Installed Homebrew at ${BREW_BIN}"
  fi

  eval "$("${BREW_BIN}" shellenv)"
}

ensure_formula() {
  local formula="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    log "${formula} already installed"
    return 0
  fi

  log "Installing ${formula}"
  "${BREW_BIN}" install "${formula}"
  success "Installed ${formula}"
}

ghostty_installed() {
  [ -d "/Applications/Ghostty.app" ] \
    || [ -d "${HOME}/Applications/Ghostty.app" ] \
    || command -v ghostty >/dev/null 2>&1
}

ensure_ghostty() {
  if ghostty_installed; then
    log "Ghostty already installed"
    return 0
  fi

  log "Installing Ghostty"
  "${BREW_BIN}" install --cask ghostty
  success "Installed Ghostty"
}

font_installed() {
  find "${HOME}/Library/Fonts" /Library/Fonts -maxdepth 1 -iname '*JetBrains*Mono*Nerd*' 2>/dev/null | grep -q .
}

ensure_font() {
  if font_installed; then
    log "JetBrainsMono Nerd Font already installed"
    return 0
  fi

  log "Installing JetBrainsMono Nerd Font"
  "${BREW_BIN}" install --cask font-jetbrains-mono-nerd-font
  success "Installed JetBrainsMono Nerd Font"
}

ensure_claude_code() {
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code already installed"
    return 0
  fi

  log "Installing Claude Code"
  "${BREW_BIN}" install --cask claude-code
  success "Installed Claude Code"
}

update_zprofile() {
  local file="${HOME}/.zprofile"
  local brew_line

  brew_line="eval \"\$(${BREW_BIN} shellenv)\""

  ensure_parent_dir "$file"
  [ -f "$file" ] || : > "$file"

  MANAGED_START="$MANAGED_START" \
  MANAGED_END="$MANAGED_END" \
  BREW_LINE="$brew_line" \
  PROXY_URL="$PROXY_URL" \
  ruby - "$file" <<'RUBY'
path = ARGV.fetch(0)
text = File.exist?(path) ? File.read(path) : ""
start_marker = ENV.fetch("MANAGED_START")
end_marker = ENV.fetch("MANAGED_END")
brew_line = ENV.fetch("BREW_LINE")
proxy_url = ENV.fetch("PROXY_URL")

managed = /(?:^|\n)#{Regexp.escape(start_marker)}\n.*?\n#{Regexp.escape(end_marker)}\n?/m
text.gsub!(managed, "\n")
text.gsub!(/^[ \t]*export http_proxy=.*\n?/m, "")
text.gsub!(/^[ \t]*export https_proxy=.*\n?/m, "")
text.gsub!(/^[ \t]*eval "\$\([^)]*brew shellenv\)".*\n?/m, "")
text.gsub!(/\n{3,}/, "\n\n")
text.sub!(/\A\n+/, "")
text.sub!(/\n+\z/, "")

block = [
  start_marker,
  brew_line,
  %{export http_proxy="#{proxy_url}"},
  %{export https_proxy="#{proxy_url}"},
  end_marker
].join("\n")

text = text.empty? ? block : "#{text}\n\n#{block}"
File.write(path, "#{text}\n")
RUBY

  success "Updated ${file}"
}

update_zshrc() {
  local file="${HOME}/.zshrc"

  ensure_parent_dir "$file"
  [ -f "$file" ] || : > "$file"

  MANAGED_START="$MANAGED_START" \
  MANAGED_END="$MANAGED_END" \
  ruby - "$file" <<'RUBY'
path = ARGV.fetch(0)
text = File.exist?(path) ? File.read(path) : ""
start_marker = ENV.fetch("MANAGED_START")
end_marker = ENV.fetch("MANAGED_END")

managed = /(?:^|\n)#{Regexp.escape(start_marker)}\n.*?\n#{Regexp.escape(end_marker)}\n?/m
starship_block = /^[ \t]*if \[\[ "\$TERM_PROGRAM" != "Apple_Terminal" \]\]; then\n[ \t]*eval "\$\(starship init zsh\)"\n[ \t]*fi\n?/m

text.gsub!(managed, "\n")
text.gsub!(/^[ \t]*eval "\$\(zoxide init zsh\)"[ \t]*\n?/m, "")
text.gsub!(starship_block, "")
text.gsub!(/^[ \t]*eval "\$\(starship init zsh\)"[ \t]*\n?/m, "")
text.gsub!(/\n{3,}/, "\n\n")
text.sub!(/\A\n+/, "")
text.sub!(/\n+\z/, "")

block = [
  start_marker,
  %{eval "$(zoxide init zsh)"},
  %{if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]]; then},
  %{  eval "$(starship init zsh)"},
  %{fi},
  end_marker
].join("\n")

text = text.empty? ? block : "#{text}\n\n#{block}"
File.write(path, "#{text}\n")
RUBY

  success "Updated ${file}"
}

generate_starship_config() {
  local file="${HOME}/.config/starship.toml"

  ensure_parent_dir "$file"

  log "Generating Starship preset ${STARSHIP_PRESET}"
  starship preset "${STARSHIP_PRESET}" -o "$file"

  STARSHIP_PALETTE="$STARSHIP_PALETTE" ruby - "$file" <<'RUBY'
path = ARGV.fetch(0)
text = File.read(path)
palette = ENV.fetch("STARSHIP_PALETTE")

if text.match?(/^palette = 'catppuccin_[^']+'\s*$/)
  text.gsub!(/^palette = 'catppuccin_[^']+'\s*$/, "palette = '#{palette}'")
else
  text = "#{text.rstrip}\npalette = '#{palette}'\n"
end

File.write(path, text.end_with?("\n") ? text : "#{text}\n")
RUBY

  success "Updated ${file}"
}

warn_on_legacy_ghostty_config() {
  local legacy_xdg="${HOME}/.config/ghostty/config"
  local legacy_macos="${HOME}/Library/Application Support/com.mitchellh.ghostty/config"
  local macos_current="${HOME}/Library/Application Support/com.mitchellh.ghostty/config.ghostty"

  if [ -f "$legacy_xdg" ] || [ -f "$legacy_macos" ] || [ -f "$macos_current" ]; then
    warn "Detected legacy or alternate Ghostty config paths. This script only updates ${HOME}/.config/ghostty/config.ghostty."
  fi
}

update_ghostty_config() {
  local file="${HOME}/.config/ghostty/config.ghostty"

  ensure_parent_dir "$file"
  [ -f "$file" ] || : > "$file"

  MANAGED_START="$MANAGED_START" \
  MANAGED_END="$MANAGED_END" \
  GHOSTTY_FONT="$GHOSTTY_FONT" \
  ruby - "$file" <<'RUBY'
path = ARGV.fetch(0)
text = File.exist?(path) ? File.read(path) : ""
start_marker = ENV.fetch("MANAGED_START")
end_marker = ENV.fetch("MANAGED_END")
font_name = ENV.fetch("GHOSTTY_FONT")

managed = /(?:^|\n)#{Regexp.escape(start_marker)}\n.*?\n#{Regexp.escape(end_marker)}\n?/m
text.gsub!(managed, "\n")
text.gsub!(/^[ \t]*font-family[ \t]*=.*\n?/m, "")
text.gsub!(/^[ \t]*background-opacity[ \t]*=.*\n?/m, "")
text.gsub!(/^[ \t]*background-blur[ \t]*=.*\n?/m, "")
text.gsub!(/^[ \t]*keybind[ \t]*=.*toggle_quick_terminal.*\n?/m, "")
text.gsub!(/\n{3,}/, "\n\n")
text.sub!(/\A\n+/, "")
text.sub!(/\n+\z/, "")

block = [
  start_marker,
  %{font-family = #{font_name}},
  %{background-opacity = 0.90},
  %{background-blur = true},
  %{keybind = ctrl+`=toggle_quick_terminal},
  end_marker
].join("\n")

text = text.empty? ? block : "#{text}\n\n#{block}"
File.write(path, "#{text}\n")
RUBY

  success "Updated ${file}"
}

update_claude_settings() {
  local file="${HOME}/.claude/settings.json"
  local parse_failed_flag="${TMPDIR:-/tmp}/claude-settings-parse-failed.$$"

  ensure_parent_dir "$file"
  if [ ! -f "$file" ]; then
    printf '{}\n' > "$file"
  fi

  rm -f "$parse_failed_flag"
  PROXY_URL="$PROXY_URL" PARSE_FAILED_FLAG="$parse_failed_flag" ruby - "$file" <<'RUBY'
require "json"

path = ARGV.fetch(0)
proxy_url = ENV.fetch("PROXY_URL")
parse_failed_flag = ENV.fetch("PARSE_FAILED_FLAG")
raw = File.read(path).strip

data =
  begin
    raw.empty? ? {} : JSON.parse(raw)
  rescue JSON::ParserError
    File.write(parse_failed_flag, "1\n")
    {}
  end

data = {} unless data.is_a?(Hash)
data["env"] = {} unless data["env"].is_a?(Hash)
data["env"]["HTTP_PROXY"] = proxy_url
data["env"]["HTTPS_PROXY"] = proxy_url

File.write(path, JSON.pretty_generate(data) + "\n")
RUBY

  if [ -f "$parse_failed_flag" ]; then
    warn "Claude settings JSON was invalid and has been reset to a minimal config with proxy env values."
    rm -f "$parse_failed_flag"
  fi

  success "Updated ${file}"
}

print_summary() {
  printf '\n'
  success "Environment setup completed."
  printf 'Run `source ~/.zprofile && source ~/.zshrc` or open a new terminal window to load the updated shell config.\n'

  if [ -s "$WARNINGS_FILE" ]; then
    printf '\nWarnings:\n'
    sed 's/^/- /' "$WARNINGS_FILE"
  fi
}

main() {
  WARNINGS_FILE="$(mktemp)"
  trap 'rm -f "$WARNINGS_FILE"' EXIT

  require_macos
  require_prerequisites

  ensure_homebrew
  update_zprofile

  ensure_formula "zoxide" "zoxide"
  ensure_formula "starship" "starship"
  ensure_ghostty
  ensure_font
  ensure_claude_code

  update_zshrc
  generate_starship_config
  warn_on_legacy_ghostty_config
  update_ghostty_config
  update_claude_settings

  print_summary
}

main "$@"
