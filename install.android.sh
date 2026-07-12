#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

if [[ -z "${TERMUX_VERSION:-}" || "${PREFIX:-}" != */com.termux/files/usr ]]; then
    echo "This installer must be run inside Termux." >&2
    exit 1
fi

DOTS_DIR="$(cd "$(dirname "$0")" && pwd)"
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--force]" >&2
    exit 1
fi

pkg update
pkg install -y bash build-essential coreutils curl diffutils git mise ncurses-utils openssh termux-api zsh

mkdir -p "$HOME/.config/mise" "$HOME/.config/jj"

links=(
    "$DOTS_DIR/.zshrc:$HOME/.zshrc"
    "$DOTS_DIR/.zprofile:$HOME/.zprofile"
    "$DOTS_DIR/.tmux.conf:$HOME/.tmux.conf"
    "$DOTS_DIR/starship.toml:$HOME/.config/starship.toml"
    "$DOTS_DIR/mise/config.android.toml:$HOME/.config/mise/config.toml"
    "$DOTS_DIR/jj/config.toml:$HOME/.config/jj/config.toml"
    "$DOTS_DIR/git/config:$HOME/.gitconfig"
)

if [[ "$FORCE" != true ]]; then
    for pair in "${links[@]}"; do
        src="${pair%%:*}"
        dest="${pair#*:}"
        if [[ -e "$dest" || -L "$dest" ]]; then
            if [[ ! -L "$dest" || "$(readlink -f "$dest")" != "$(readlink -f "$src")" ]]; then
                echo "Conflict: $dest already exists. Re-run with --force to replace it." >&2
                exit 1
            fi
        fi
    done
fi

for pair in "${links[@]}"; do
    src="${pair%%:*}"
    dest="${pair#*:}"
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        continue
    fi
    rm -rf "$dest"
    ln -s "$src" "$dest"
done

mise install

if [[ "${SHELL:-}" != "$PREFIX/bin/zsh" ]]; then
    echo ""
    echo "Set zsh as your Termux login shell with: chsh -s zsh"
fi

echo "Termux dotfiles installed. Restart the shell to load them."
