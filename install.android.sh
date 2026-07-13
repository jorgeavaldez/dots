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
pkg install -y bash build-essential coreutils curl diffutils file gdbm git git-delta gnupg jq libandroid-posix-semaphore libandroid-support libbz2 libcrypt libexpat libffi liblzma libsqlite mise ncurses ncurses-ui-libs ncurses-utils openssl openssh pkg-config proot readline ripgrep termux-api zlib zsh
pkg install -y glibc-repo
pkg install -y glibc-runner
pkg uninstall -y nodejs python rust 2>/dev/null || true

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

# Running from ~/dots would also load ~/dots/mise/config.toml as a project
# config and merge the desktop tool list into the Android installation. The
# proot bindings let mise install and verify standard ARM64 glibc toolchains;
# wrappers keep those toolchains inside the same compatibility boundary later.
(
    cd "$HOME"
    proot \
        -b "$PREFIX/bin:/bin" \
        -b "$PREFIX/bin:/usr/bin" \
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf" \
        -b "$PREFIX/etc/tls/cert.pem:/etc/ssl/certs/ca-certificates.crt" \
        -b "$PREFIX/glibc/lib/ld-linux-aarch64.so.1:/lib/ld-linux-aarch64.so.1" \
        env -u LD_PRELOAD \
        LD_LIBRARY_PATH="$PREFIX/glibc/lib" \
        MISE_LIBC=glibc \
        MISE_OS=linux \
        mise install
)

for runtime in node python rust; do
    install_root="$HOME/.local/share/mise/installs/$runtime"
    [[ -d "$install_root" ]] || continue
    while IFS= read -r -d '' executable; do
        [[ "$executable" == *.termux-glibc ]] && continue
        if file "$executable" | grep -q 'ELF.*dynamically linked'; then
            real_executable="$executable.termux-glibc"
            mv "$executable" "$real_executable"
            cat >"$executable" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec proot \\
    -b "\$PREFIX/bin:/bin" \\
    -b "\$PREFIX/bin:/usr/bin" \\
    -b "\$PREFIX/etc/resolv.conf:/etc/resolv.conf" \\
    -b "\$PREFIX/etc/tls/cert.pem:/etc/ssl/certs/ca-certificates.crt" \\
    -b "\$PREFIX/glibc/lib/ld-linux-aarch64.so.1:/lib/ld-linux-aarch64.so.1" \\
    env -u LD_PRELOAD LD_LIBRARY_PATH="\$PREFIX/glibc/lib" \\
    "$real_executable" "\$@"
EOF
            chmod +x "$executable"
        fi
    done < <(find "$install_root" -type f -perm -u+x -print0)
done

if [[ "${SHELL:-}" != "$PREFIX/bin/zsh" ]]; then
    echo ""
    echo "Set zsh as your Termux login shell with: chsh -s zsh"
fi

echo "Termux dotfiles installed. Restart the shell to load them."
