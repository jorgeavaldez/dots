#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

if [[ -z "${TERMUX_VERSION:-}" || "${PREFIX:-}" != */com.termux/files/usr ]]; then
    echo "This installer must be run inside Termux." >&2
    exit 1
fi

if [[ "$(uname -m)" != "aarch64" ]]; then
    echo "This installer currently supports only ARM64 Termux devices." >&2
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
xargs pkg install -y <"$DOTS_DIR/termux/packages.txt"
xargs npm install --global --ignore-scripts <"$DOTS_DIR/termux/npm-packages.txt"

mkdir -p "$HOME/.config/jj" "$HOME/.local/bin" "$HOME/.local/libexec"
install -d -m 700 "$HOME/.local/share/jj-android/workspaces"

jj_url="$(curl -fsSL https://api.github.com/repos/jj-vcs/jj/releases/latest |
    jq -er '.assets[] | select(.name | test("aarch64-unknown-linux-musl\\.tar\\.gz$")) | .browser_download_url' |
    head -n 1)"
jj_tmp="$(mktemp -d)"
trap 'rm -rf "$jj_tmp"' EXIT
curl -fsSL "$jj_url" -o "$jj_tmp/jj.tar.gz"
tar -xzf "$jj_tmp/jj.tar.gz" -C "$jj_tmp"
jj_binary="$(find "$jj_tmp" -type f -name jj -perm -u+x -print -quit)"
if [[ -z "$jj_binary" ]]; then
    echo "The Jujutsu release archive did not contain an executable named jj." >&2
    exit 1
fi
install -m 755 "$jj_binary" "$HOME/.local/libexec/jj"

links=(
    "$DOTS_DIR/.zshrc:$HOME/.zshrc"
    "$DOTS_DIR/.zprofile:$HOME/.zprofile"
    "$DOTS_DIR/.tmux.conf:$HOME/.tmux.conf"
    "$DOTS_DIR/starship.toml:$HOME/.config/starship.toml"
    "$DOTS_DIR/jj/config.toml:$HOME/.config/jj/config.toml"
    "$DOTS_DIR/git/config:$HOME/.gitconfig"
    "$DOTS_DIR/termux/jj-wrapper.sh:$HOME/.local/bin/jj"
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

if [[ "${SHELL:-}" != "$PREFIX/bin/zsh" ]]; then
    echo ""
    echo "Set zsh as your Termux login shell with: chsh -s zsh"
fi

echo "Termux dotfiles and essential tools installed. Restart the shell to load them."
