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
SVDIR="$PREFIX/var/service" LOGDIR="$PREFIX/var/log" service-daemon start >/dev/null 2>&1 || true
SVDIR="$PREFIX/var/service" sv-enable ssh-agent
xargs npm install --global --ignore-scripts <"$DOTS_DIR/termux/npm-packages.txt"
if [[ "${HERDR_ENV:-}" == "1" ]]; then
    echo "Skipping Herdr update inside an active Herdr session; run 'herdr update' after detaching."
else
    "$HOME/.local/bin/herdr" update
fi
"$HOME/.local/bin/herdr" plugin link "$DOTS_DIR/termux/herdr-notifications" --enabled >/dev/null

mkdir -p "$HOME/.config/jj" "$HOME/.local/bin" "$HOME/.local/libexec"
install -d -m 700 "$HOME/.local/share/jj-android/workspaces"

jj_url="$(curl -fsSL https://api.github.com/repos/jj-vcs/jj/releases/latest |
    jq -er '.assets[] | select(.name | test("aarch64-unknown-linux-musl\\.tar\\.gz$")) | .browser_download_url' |
    head -n 1)"
release_tmp="$(mktemp -d)"
trap 'rm -rf "$release_tmp"' EXIT
curl -fsSL "$jj_url" -o "$release_tmp/jj.tar.gz"
tar -xzf "$release_tmp/jj.tar.gz" -C "$release_tmp"
jj_binary="$(find "$release_tmp" -type f -name jj -perm -u+x -print -quit)"
if [[ -z "$jj_binary" ]]; then
    echo "The Jujutsu release archive did not contain an executable named jj." >&2
    exit 1
fi
install -m 755 "$jj_binary" "$HOME/.local/libexec/jj"

fnox_asset="$(curl -fsSL https://api.github.com/repos/jdx/fnox/releases/latest |
    jq -ce '.assets[] | select(.name == "fnox-aarch64-unknown-linux-musl.tar.gz")')"
fnox_digest="$(jq -er '.digest | select(startswith("sha256:"))' <<<"$fnox_asset")"
curl -fsSL "$(jq -er '.browser_download_url' <<<"$fnox_asset")" -o "$release_tmp/fnox.tar.gz"
printf '%s  %s\n' "${fnox_digest#sha256:}" "$release_tmp/fnox.tar.gz" | sha256sum --check
# Extract only the executable from the verified ARM64 static-musl release.
tar -xzf "$release_tmp/fnox.tar.gz" -C "$release_tmp" fnox
"$release_tmp/fnox" --version
install -m 755 "$release_tmp/fnox" "$HOME/.local/bin/fnox"

links=(
    "$DOTS_DIR/.zshenv:$HOME/.zshenv"
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
