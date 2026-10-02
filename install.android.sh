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
if [[ $# -gt 1 || ($# -eq 1 && "$1" != "--dry-run") ]]; then
    echo "Usage: $0 [--dry-run] (conflicts are preserved by bootstrap.nu; no --force)" >&2
    exit 1
fi
if [[ "${1:-}" == "--dry-run" ]]; then
    exec nu --no-config-file "$DOTS_DIR/bootstrap.nu" --dry-run
fi

# Native mise seeds bootstrap. Native Nu provides working Android DNS and
# Node/npm provide Android npm execution; other verified tools belong to mise.
pkg update
xargs pkg install -y <"$DOTS_DIR/termux/packages.txt"
# The same native mise selection used by bootstrap owns optional pkg roots.
android_packages="$(nu --no-config-file "$DOTS_DIR/bootstrap.nu" --android-packages)"
if [[ -n "$android_packages" ]]; then
    printf '%s\n' "$android_packages" | xargs pkg install -y
fi
SVDIR="$PREFIX/var/service" LOGDIR="$PREFIX/var/log" service-daemon start >/dev/null 2>&1 || true
SVDIR="$PREFIX/var/service" sv-enable ssh-agent
# Pi's supported native Termux distribution remains an explicit exception.
xargs npm install --global --ignore-scripts <"$DOTS_DIR/termux/npm-packages.txt"
if [[ "${HERDR_ENV:-}" == "1" ]]; then
    echo "Skipping Herdr update inside an active Herdr session; run 'herdr update' after detaching."
else
    "$HOME/.local/bin/herdr" update
fi
"$HOME/.local/bin/herdr" plugin link "$DOTS_DIR/termux/herdr-notifications" --enabled >/dev/null

# Preserve the shared-storage jj wrapper's binary layout. Shared bootstrap owns
# the wrapper/config links and their conflict handling, not this seed installer.
mkdir -p "$HOME/.local/bin" "$HOME/.local/libexec"
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

nu --no-config-file "$DOTS_DIR/bootstrap.nu"
