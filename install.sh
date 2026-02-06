#!/bin/bash

DOTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create parent directories if needed
mkdir -p ~/.config/opencode
mkdir -p ~/.config/jj
mkdir -p ~/.config

# Symlink dotfiles
ln -sf "$DOTS_DIR/.zshrc" ~/.zshrc
ln -sf "$DOTS_DIR/.tmux.conf" ~/.tmux.conf
ln -sf "$DOTS_DIR/opencode.json" ~/.config/opencode/opencode.json
ln -sf "$DOTS_DIR/starship.toml" ~/.config/starship.toml
ln -sfn "$DOTS_DIR/wezterm" ~/.config/wezterm
ln -sf "$DOTS_DIR/config.toml" ~/.config/mise/config.toml
ln -sf "$DOTS_DIR/jj/config.toml" ~/.config/jj/config.toml
ln -sf "$DOTS_DIR/git/config" ~/.gitconfig

echo "Dotfiles symlinked!"
