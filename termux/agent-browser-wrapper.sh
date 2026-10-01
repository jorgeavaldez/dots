#!/data/data/com.termux/files/usr/bin/sh

# Keep upstream's CLI/daemon protocol intact; only supply its missing DNS file.
: "${PREFIX:?This launcher requires Termux PREFIX}"
: "${TMPDIR:?This launcher requires TMPDIR}"
binary="$PREFIX/lib/node_modules/agent-browser/bin/agent-browser-linux-musl-arm64"
resolver="$PREFIX/etc/resolv.conf"
if [ ! -x "$binary" ]; then
    printf 'agent-browser: missing upstream binary: %s\nRun: npm install --global --ignore-scripts agent-browser\n' "$binary" >&2
    exit 1
fi
if [ ! -r "$resolver" ]; then
    printf 'agent-browser: missing Termux DNS configuration: %s\n' "$resolver" >&2
    exit 1
fi

umask 077
work=$(mktemp -d "$TMPDIR/agent-browser.XXXXXXXX") || exit 1
trap 'rm -rf "$work"' 0
mkfifo "$work/stdout" "$work/stderr" "$work/status" || exit 1

# PRoot waits for detached descendants. Stream only the CLI's output through
# FIFOs, and signal its exit separately: the daemon and its tracer can stay alive
# without holding the caller's stdout/stderr open. Never use --kill-on-exit.
exec 3<&0
(
    runner=
    trap 'kill "$runner" 2>/dev/null; exit 143' HUP INT TERM
    # Expansion belongs to the child shell; the launcher must pass literal code.
    # shellcheck disable=SC2016
    "$PREFIX/bin/proot" -b "$resolver:/etc/resolv.conf" "$PREFIX/bin/sh" -c '
        work=$1
        shift
        "$@" >"$work/stdout" 2>"$work/stderr"
        code=$?
        printf "%s\n" "$code" >"$work/result"
        printf "%s\n" "$code" >"$work/status"
    ' sh "$work" "$binary" "$@" <&3 3<&- &
    runner=$!
    exec 3<&-
    wait "$runner"
    code=$?
    # A launch failure must unblock the readers even if the CLI never ran.
    if [ -d "$work" ] && [ ! -f "$work/result" ]; then
        : >"$work/stdout"
        : >"$work/stderr"
        printf '%s\n' "$code" >"$work/status"
    fi
) </dev/null >"$work/proot.log" 2>&1 &
worker=$!
exec 3<&-

cat "$work/stdout" &
stdout_pid=$!
cat "$work/stderr" >&2 &
stderr_pid=$!
trap 'kill "$worker" "$stdout_pid" "$stderr_pid" 2>/dev/null; exit 130' INT
trap 'kill "$worker" "$stdout_pid" "$stderr_pid" 2>/dev/null; exit 143' HUP TERM

if ! read -r code <"$work/status"; then
    kill "$worker" "$stdout_pid" "$stderr_pid" 2>/dev/null
    printf 'agent-browser: launcher exited without a command status\n' >&2
    exit 1
fi
wait "$stdout_pid" "$stderr_pid"
cat "$work/proot.log" >&2
exit "$code"
