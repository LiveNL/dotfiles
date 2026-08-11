#!/usr/bin/env bash
# Sets up symlinks from dotfiles to their expected locations.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "Backing up existing $dst → ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    echo "  $dst → $src"
}

echo "Installing dotfiles symlinks..."
link "$REPO/.config"    "$HOME/.config"
link "$REPO/.claude"    "$HOME/.claude"
link "$REPO/.zshrc"     "$HOME/.zshrc"
link "$REPO/.tmux.conf" "$HOME/.tmux.conf"
link "$REPO/.local/bin/claude-color" "$HOME/.local/bin/claude-color"

if [ "$(uname -s)" = "Darwin" ]; then
    echo "Installing LaunchAgents..."
    for plist in "$REPO"/.config/launchd/*.plist; do
        [ -e "$plist" ] || continue
        label="$(basename "$plist" .plist)"
        target="$HOME/Library/LaunchAgents/$(basename "$plist")"
        link "$plist" "$target"
        launchctl bootout "gui/$UID/$label" 2>/dev/null || true
        launchctl bootstrap "gui/$UID" "$target"
    done
fi

if [ "${SKIP_BREW:-}" = "1" ]; then
    echo "Skipping brew bundle (SKIP_BREW=1)"
elif command -v brew >/dev/null 2>&1; then
    echo "Installing Brewfile packages..."
    brew bundle --file="$REPO/Brewfile"
else
    echo "  Skipping Brewfile — install Homebrew first: https://brew.sh"
fi

cat <<'EOF'

Not handled here (machine-local or private):
  ~/.gitconfig            — gitignored on purpose, write it per machine
  ~/.openai_api_key       — optional, read by .zshrc if present
  ~/.anthropic_api_key    — optional, read by .zshrc if present
  ~/.claude/CLAUDE.md     — run dotfiles-private/install.sh
  ~/.claude/skills        — run dotfiles-private/install.sh
  ~/.claude/hooks         — clone LiveNL/claude-tmux-hooks, then dotfiles-private/install.sh

Done.
EOF
