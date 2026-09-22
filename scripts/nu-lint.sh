#!/usr/bin/env bash
set -euo pipefail

mode="${1:?Usage: nu-lint.sh format|check [files...]}"
shift
case "$mode" in
    format | check) ;;
    *) exit 2 ;;
esac

sandbox="$(mktemp -d "${TMPDIR:-/tmp}/dots-nu-lint.XXXXXX")"
trap 'rm -rf "$sandbox"' EXIT

# Include new, non-ignored files (including tests), not just committed scripts.
if [ "$#" -eq 0 ]; then
    git ls-files --cached --others --exclude-standard -z -- '*.nu' >"$sandbox/files"
    while IFS= read -r -d '' file; do
        [ ! -f "$file" ] || set -- "$@" "$file"
    done <"$sandbox/files"
fi
[ "$#" -gt 0 ] || exit 0

mkdir -p "$sandbox/home" "$sandbox/config" "$sandbox/cache" "$sandbox/data"
isolated() {
    env -i PATH="$PATH" HOME="$sandbox/home" \
        XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" \
        XDG_DATA_HOME="$sandbox/data" "$@"
}

# `use`/`source` resolve at parse time. Generate real integrations in isolation;
# never execute env.nu, config.nu, bootstrap, or a fnox/secret-resolution hook.
# Run away from the checkout so mise cannot load project configuration.
(
    cd "$sandbox"
    isolated nu --no-config-file -c '
        mkdir $nu.cache-dir $nu.data-dir
        ^mise activate nu | save --force ($nu.cache-dir | path join "mise.nu")
        ^zoxide init nushell | save --force ($nu.data-dir | path join "zoxide.nu")
    '
)

if [ "$mode" = format ]; then
    isolated nufmt "$@"
else
    isolated nufmt --dry-run "$@"
    for file in "$@"; do
        printf 'Checking Nu syntax: %s\n' "$file"
        # nu-check returns a boolean; explicitly turn false into a failing exit.
        isolated env NU_CHECK_FILE="$file" nu --no-config-file -c '
            if not (nu-check --debug $env.NU_CHECK_FILE) { exit 1 }
        '
    done
fi
