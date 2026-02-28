# Shared PATH setup for login and interactive shells.

if [[ -n "${DOTS_ZSH_PATH_LOADED:-}" ]]; then
    return 0
fi
DOTS_ZSH_PATH_LOADED=1

if [ -f "$HOME/bin/google-cloud-sdk/path.zsh.inc" ]; then
    . "$HOME/bin/google-cloud-sdk/path.zsh.inc"
fi

if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    export PATH="${PATH}:${ANDROID_SDK_ROOT}/emulator"
    export PATH="${PATH}:${ANDROID_SDK_ROOT}/platform-tools"
    export PATH="${PATH}:${ANDROID_SDK_ROOT}/tools"
    export PATH="${PATH}:${ANDROID_SDK_ROOT}/tools/bin"
fi

if [[ -n "${JAVA_HOME:-}" ]]; then
    export PATH="${JAVA_HOME}/bin:${PATH}"
fi

if [[ -n "${GOPATH:-}" ]]; then
    export PATH="${GOPATH//://bin:}/bin:$PATH"
fi

export PATH="/usr/local/sbin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="${PATH}:$HOME/bin"
export PATH="$HOME/.ebcli-virtual-env/executables:${PATH}"
export PATH="${PATH}:$HOME/.foundry/bin"
export PATH="$HOME/.local/share/solana/install/active_release/bin:${PATH}"

if [[ -n "${BUN_INSTALL:-}" ]]; then
    export PATH="$BUN_INSTALL/bin:${PATH}"
fi

export PATH="$HOME/proj/solidity-one-liners/bin:${PATH}"
export PATH="$HOME/proj/nimlsp:$PATH"
export PATH="$HOME/.nimble/bin:${PATH}"
export PATH="$HOME/.cargo/bin:${PATH}"
export PATH="$HOME/go/bin:${PATH}"
export PATH="$HOME/.atuin/bin:${PATH}"

if [[ -n "${FLYCTL_INSTALL:-}" ]]; then
    export PATH="$FLYCTL_INSTALL/bin:$PATH"
fi

export PATH="${HOME}/dots/scripts:${PATH}"
export PATH="$PATH:$HOME/.lmstudio/bin"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.claude/local:$PATH"

# obsidian cli
export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac

if [ -d /opt/homebrew/bin ]; then export PATH="/opt/homebrew/bin:$PATH"; fi
if [ -d /opt/homebrew/opt/postgresql@17/bin ]; then export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"; fi

if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

if [ -f /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
if [ -f /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
