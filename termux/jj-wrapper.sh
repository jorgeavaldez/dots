#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

REAL_JJ="$HOME/.local/libexec/jj"
SHARED_PREFIX="/storage/emulated"
STATE_ROOT="$HOME/.local/share/jj-android/workspaces"
BOOTSTRAP_TMP=""

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

cleanup_bootstrap() {
    if [[ -n "$BOOTSTRAP_TMP" ]]; then
        rm -rf -- "$BOOTSTRAP_TMP"
        BOOTSTRAP_TMP=""
    fi
}

canonical_path() {
    if [[ "$1" == /* ]]; then
        realpath -m -- "$1"
    else
        realpath -m -- "$PWD/$1"
    fi
}

is_shared_path() {
    [[ "$1" == "$SHARED_PREFIX" || "$1" == "$SHARED_PREFIX/"* ]]
}

state_dir_for() {
    local workspace_root="$1"
    local workspace_id

    workspace_id="$(printf '%s' "$workspace_root" | sha256sum | cut -d ' ' -f 1)"
    printf '%s/%s\n' "$STATE_ROOT" "$workspace_id"
}

shared_identity_for() {
    local workspace_root="$1"
    local identity

    identity="$(stat -c '%u:%g' "$workspace_root")" ||
        fail "could not read shared-storage ownership for $workspace_root"
    [[ "$identity" =~ ^[0-9]+:[0-9]+$ ]] ||
        fail "invalid shared-storage ownership for $workspace_root: $identity"
    printf '%s\n' "$identity"
}

find_workspace_root() {
    local path="$1"
    local git_root

    if [[ "${path##*/}" == ".jj" ]]; then
        path="${path%/*}"
    elif [[ -f "$path" ]]; then
        path="${path%/*}"
    fi

    while is_shared_path "$path"; do
        if [[ -e "$path/.jj" || -L "$path/.jj" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
        [[ "$path" == "$SHARED_PREFIX" ]] && break
        path="${path%/*}"
        [[ -n "$path" ]] || path="/"
    done

    path="$1"
    [[ -d "$path" ]] || path="${path%/*}"
    if git_root="$(git -c safe.directory='*' -C "$path" rev-parse --show-toplevel 2>/dev/null)"; then
        git_root="$(canonical_path "$git_root")"
        if is_shared_path "$git_root"; then
            printf '%s\n' "$git_root"
            return 0
        fi
    fi

    printf '%s\n' "$1"
}

validate_private_state() {
    local workspace_root="$1"
    local state_dir="$2"
    local recorded_root

    [[ -d "$state_dir/.jj/repo" && -d "$state_dir/.jj/working_copy" ]] ||
        fail "private Jujutsu metadata is missing or incomplete at $state_dir"
    [[ -f "$state_dir/workspace-path" ]] ||
        fail "private Jujutsu metadata has no workspace-path marker at $state_dir"

    IFS= read -r recorded_root <"$state_dir/workspace-path" || true
    [[ "$recorded_root" == "$workspace_root" ]] ||
        fail "private Jujutsu metadata belongs to $recorded_root, not $workspace_root"
}

validate_mountpoint() {
    local workspace_root="$1"
    local unexpected_entry

    [[ -d "$workspace_root/.jj" && ! -L "$workspace_root/.jj" ]] ||
        fail "the shared workspace must contain an empty .jj directory: $workspace_root/.jj"

    unexpected_entry="$(find "$workspace_root/.jj" -mindepth 1 -print -quit)"
    [[ -z "$unexpected_entry" ]] ||
        fail "refusing to overlay non-empty shared metadata: $workspace_root/.jj"
}

run_overlaid_jj() {
    local workspace_root="$1"
    local state_dir="$2"
    shift 2

    proot --kill-on-exit \
        -i "$(shared_identity_for "$workspace_root")" \
        -b "$state_dir/.jj:$workspace_root/.jj" \
        -w "$PWD" \
        "$REAL_JJ" "$@"
}

print_bootstrap_error() {
    local workspace_root="$1"

    cat >&2 <<EOF
error: this Android shared-storage workspace has not been bootstrapped.

Repository:
  $workspace_root

Initialize it with:
  jj android init "$workspace_root"

This keeps .jj in Termux private storage while leaving working files here.
EOF
    exit 1
}

bootstrap_workspace() {
    local destination="${1:-.}"
    local workspace_root
    local state_dir
    local git_root
    local unexpected_entry
    local unmerged_files
    local staged_status

    if [[ "$destination" == "-h" || "$destination" == "--help" ]]; then
        cat <<'EOF'
Usage:
  jj android init [DESTINATION]

Initialize a Git-backed Jujutsu workspace under Android shared storage while
keeping its .jj metadata in Termux private storage.
EOF
        return 0
    fi
    [[ $# -le 1 ]] || fail "usage: jj android init [DESTINATION]"

    workspace_root="$(canonical_path "$destination")"
    is_shared_path "$workspace_root" ||
        fail "Android bootstrap is only for paths under $SHARED_PREFIX; use jj git init elsewhere"
    [[ "$workspace_root" == "$SHARED_PREFIX/"*/* ]] ||
        fail "refusing to initialize the shared-storage volume root: $workspace_root"
    command -v git >/dev/null 2>&1 || fail "git is not installed; rerun install.android.sh"
    command -v flock >/dev/null 2>&1 || fail "flock is not installed; rerun install.android.sh"
    command -v proot >/dev/null 2>&1 || fail "proot is not installed; rerun install.android.sh"

    mkdir -p "$workspace_root"
    state_dir="$(state_dir_for "$workspace_root")"
    install -d -m 700 "$STATE_ROOT"

    exec 9>"$STATE_ROOT/bootstrap.lock"
    flock 9

    if [[ -e "$state_dir" || -L "$state_dir" ]]; then
        validate_private_state "$workspace_root" "$state_dir"
        if [[ ! -e "$workspace_root/.jj" && ! -L "$workspace_root/.jj" ]]; then
            mkdir "$workspace_root/.jj"
        fi
        validate_mountpoint "$workspace_root"
        run_overlaid_jj "$workspace_root" "$state_dir" -R "$workspace_root" status
        printf '\nJujutsu is already ready for this workspace.\nPrivate metadata: %s/.jj\n' "$state_dir"
        return 0
    fi

    if [[ -e "$workspace_root/.jj" || -L "$workspace_root/.jj" ]]; then
        if [[ -d "$workspace_root/.jj" && ! -L "$workspace_root/.jj" ]]; then
            unexpected_entry="$(find "$workspace_root/.jj" -mindepth 1 -print -quit)"
            if [[ -z "$unexpected_entry" ]]; then
                fail "the shared .jj mount point exists but its private metadata is missing; restore the private state before reinitializing"
            fi
        fi
        fail "refusing to replace existing shared Jujutsu metadata: $workspace_root/.jj"
    fi

    if [[ -e "$workspace_root/.git" || -L "$workspace_root/.git" ]]; then
        git_root="$(git -c safe.directory="$workspace_root" -C "$workspace_root" rev-parse --show-toplevel 2>/dev/null)" ||
            fail "$workspace_root/.git is not a valid Git repository"
        git_root="$(canonical_path "$git_root")"
        [[ "$git_root" == "$workspace_root" ]] ||
            fail "the Git repository root is $git_root; run jj android init there"
    else
        if git_root="$(git -c safe.directory='*' -C "$workspace_root" rev-parse --show-toplevel 2>/dev/null)"; then
            git_root="$(canonical_path "$git_root")"
            fail "$workspace_root is inside the Git repository at $git_root; initialize that root instead"
        fi
        git init "$workspace_root"
    fi

    unmerged_files="$(git -c safe.directory="$workspace_root" -C "$workspace_root" ls-files -u)" ||
        fail "could not inspect unresolved Git entries in $workspace_root"
    [[ -z "$unmerged_files" ]] ||
        fail "the Git repository has unresolved conflicts; resolve them before Android bootstrap"

    if git -c safe.directory="$workspace_root" -C "$workspace_root" diff --cached --quiet --; then
        staged_status=0
    else
        staged_status=$?
    fi
    case "$staged_status" in
        0) ;;
        1) fail "the Git staging area is not empty; commit or unstage it before Android bootstrap" ;;
        *) fail "could not inspect the Git staging area in $workspace_root" ;;
    esac

    git_root="$(git -c safe.directory="$workspace_root" -C "$workspace_root" rev-parse --absolute-git-dir)" ||
        fail "could not resolve the Git metadata for $workspace_root"
    git_root="$(canonical_path "$git_root")"

    BOOTSTRAP_TMP="$(mktemp -d "$STATE_ROOT/.bootstrap.XXXXXX")"
    trap cleanup_bootstrap EXIT

    "$REAL_JJ" git init --git-repo="$git_root" "$BOOTSTRAP_TMP/shadow"
    (
        cd "$BOOTSTRAP_TMP/shadow"
        "$REAL_JJ" config set --repo working-copy.exec-bit-change ignore
    )

    mkdir "$BOOTSTRAP_TMP/state"
    mv "$BOOTSTRAP_TMP/shadow/.jj" "$BOOTSTRAP_TMP/state/.jj"
    printf '%s\n' "$workspace_root" >"$BOOTSTRAP_TMP/state/workspace-path"
    chmod 700 "$BOOTSTRAP_TMP/state"
    mv "$BOOTSTRAP_TMP/state" "$state_dir"
    mkdir "$workspace_root/.jj"

    validate_private_state "$workspace_root" "$state_dir"
    validate_mountpoint "$workspace_root"
    run_overlaid_jj "$workspace_root" "$state_dir" -R "$workspace_root" status

    printf '\nAndroid shared-storage bootstrap complete.\n'
    printf 'Workspace: %s\n' "$workspace_root"
    printf 'Private metadata: %s/.jj\n' "$state_dir"

    cleanup_bootstrap
    trap - EXIT
}

[[ -x "$REAL_JJ" ]] || fail "real Jujutsu binary not found at $REAL_JJ; rerun install.android.sh"

if [[ "${1:-}" == "android" ]]; then
    case "${2:-}" in
        init)
            shift 2
            bootstrap_workspace "$@"
            exit 0
            ;;
        -h | --help | "")
            cat <<'EOF'
Android shared-storage support

Usage:
  jj android init [DESTINATION]

This initializes Jujutsu with private .jj metadata while keeping working files
and the colocated Git repository on Android shared storage.
EOF
            exit 0
            ;;
        *)
            fail "usage: jj android init [DESTINATION]"
            ;;
    esac
fi

repository_path=""
arguments=("$@")
for ((i = 0; i < ${#arguments[@]}; i++)); do
    case "${arguments[$i]}" in
        -R | --repository)
            if ((i + 1 < ${#arguments[@]})); then
                repository_path="${arguments[$((i + 1))]}"
            fi
            ;;
        --repository=*) repository_path="${arguments[$i]#--repository=}" ;;
        -R?*) repository_path="${arguments[$i]#-R}" ;;
    esac
done

command_target="${repository_path:-$PWD}"
command_target="$(canonical_path "$command_target")"

for ((i = 0; i + 1 < ${#arguments[@]}; i++)); do
    if [[ "${arguments[$i]}" == "git" && "${arguments[$((i + 1))]}" == "init" ]]; then
        init_destination="."
        skip_next=false
        for ((j = i + 2; j < ${#arguments[@]}; j++)); do
            if [[ "$skip_next" == true ]]; then
                skip_next=false
                continue
            fi
            case "${arguments[$j]}" in
                --colocate | --no-colocate) ;;
                --object-hash | --git-repo)
                    skip_next=true
                    ;;
                --object-hash=* | --git-repo=* | -*) ;;
                *) init_destination="${arguments[$j]}" ;;
            esac
        done
        init_destination="$(canonical_path "$init_destination")"
        if is_shared_path "$init_destination"; then
            print_bootstrap_error "$init_destination"
        fi
        break
    fi
done

if ! is_shared_path "$command_target"; then
    exec "$REAL_JJ" "$@"
fi

workspace_root="$(find_workspace_root "$command_target")"
state_dir="$(state_dir_for "$workspace_root")"

if [[ ! -e "$workspace_root/.jj" && ! -L "$workspace_root/.jj" ]]; then
    if [[ -e "$state_dir" || -L "$state_dir" ]]; then
        fail "private metadata exists but the shared .jj mount point is missing; run jj android init \"$workspace_root\" to repair it"
    fi
    print_bootstrap_error "$workspace_root"
fi

if [[ ! -e "$state_dir" && ! -L "$state_dir" ]]; then
    fail "private Jujutsu metadata is missing for $workspace_root; restore $state_dir before reinitializing"
fi

validate_private_state "$workspace_root" "$state_dir"
validate_mountpoint "$workspace_root"
command -v proot >/dev/null 2>&1 || fail "proot is not installed; rerun install.android.sh"
exec proot --kill-on-exit \
    -i "$(shared_identity_for "$workspace_root")" \
    -b "$state_dir/.jj:$workspace_root/.jj" \
    -w "$PWD" \
    "$REAL_JJ" "$@"
