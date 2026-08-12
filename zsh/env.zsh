# Shared environment for login and interactive shells.

# Termius/SSH sometimes lands with LANG=C. tmux decides whether the client is
# UTF-8 from the locale at attach time; non-UTF-8 makes Unicode punctuation and
# TUI glyphs render as underscores or other fallback garbage.
if [[ -n "${TERMUX_VERSION:-}" ]]; then
    # Android's Bionic libc supports en_US.UTF-8 directly; locale-gen is neither
    # available nor necessary in Termux.
    unset LC_ALL
    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
else
    if [[ -z "${LC_ALL:-}" || "${LC_ALL:-}" == C || "${LC_ALL:-}" == POSIX ]]; then
        unset LC_ALL
    fi
    if [[ -z "${LANG:-}" || "${LANG:-}" == C || "${LANG:-}" == POSIX ]]; then
        export LANG=en_US.UTF-8
    fi
    if [[ -z "${LC_CTYPE:-}" || "${LC_CTYPE:-}" == C || "${LC_CTYPE:-}" == POSIX ]]; then
        export LC_CTYPE=en_US.UTF-8
    fi
fi

if [[ -f "$HOME/dots/zsh/colima-testcontainers.zsh" ]]; then
    source "$HOME/dots/zsh/colima-testcontainers.zsh"
fi

if [[ -n "${DOTS_ZSH_ENV_LOADED:-}" ]]; then
    return 0
fi
DOTS_ZSH_ENV_LOADED=1

if [[ -n "${TERMUX_VERSION:-}" ]]; then
    if [[ -o interactive ]] && command -v keychain >/dev/null 2>&1 && [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        eval "$(keychain --eval --quiet id_ed25519)"
    fi
# I like to use 1password to manage my ssh keys on desktop Linux.
elif [[ ! -S "${SSH_AUTH_SOCK:-}" && "$(uname)" == "Linux" ]]; then
    export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

export EDITOR="nvim"
export BAT_THEME="ansi"
export GOOSE_CLI_THEME="ansi"

export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"

export BUN_INSTALL="$HOME/.bun"
export FLYCTL_INSTALL="$HOME/.fly"
export GOPATH="$HOME/proj/go"

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export CLOUDSDK_DEVAPPSERVER_PYTHON="/usr/bin/python2"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

if [[ -f "$HOME/dots/secrets.sh" ]]; then
    source "$HOME/dots/secrets.sh" || true
fi
