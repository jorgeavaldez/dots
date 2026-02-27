# Shared environment for login and interactive shells.

if [[ -n "${DOTS_ZSH_ENV_LOADED:-}" ]]; then
    return 0
fi
DOTS_ZSH_ENV_LOADED=1

# I like to use 1password to manage my ssh keys.
# Typically I bypass this by restarting the ssh agent manually.
if [[ ! -S "${SSH_AUTH_SOCK:-}" && "$(uname)" == "Linux" ]]; then
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
    source "$HOME/dots/secrets.sh"
fi
