# Minimal environment loaded by every Zsh, including non-interactive SSH commands.
# Reuse an existing SSH agent here, but never start or unlock one where a
# passphrase prompt is not possible.

if [[ "$OSTYPE" == linux* && ! -S "${SSH_AUTH_SOCK:-}" ]]; then
    if [[ -S "$HOME/.1password/agent.sock" ]]; then
        export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
    else
        keychain_env="$HOME/.keychain/${HOST%%.*}-sh"
        if [[ -r "$keychain_env" ]]; then
            source "$keychain_env"
            if [[ ! -S "${SSH_AUTH_SOCK:-}" ]]; then
                unset SSH_AUTH_SOCK SSH_AGENT_PID
            fi
        fi
        unset keychain_env
    fi
fi
