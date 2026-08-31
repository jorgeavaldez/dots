# Minimal environment loaded by every Zsh, including non-interactive SSH commands.
# Reuse an existing SSH agent here, but never start or unlock one where a
# passphrase prompt is not possible.

if [[ -n "${TERMUX_VERSION:-}" ]]; then
    termux_ssh_auth_sock="$PREFIX/var/run/ssh-agent.socket"
    if [[ -n "${SSH_AGENT_PID:-}" || ! -S "${SSH_AUTH_SOCK:-}" ]]; then
        if [[ -S "$termux_ssh_auth_sock" ]]; then
            export SSH_AUTH_SOCK="$termux_ssh_auth_sock"
            unset SSH_AGENT_PID
        elif [[ ! -S "${SSH_AUTH_SOCK:-}" ]]; then
            unset SSH_AUTH_SOCK SSH_AGENT_PID
        fi
    fi
    unset termux_ssh_auth_sock
elif [[ "$OSTYPE" == linux* && ! -S "${SSH_AUTH_SOCK:-}" ]]; then
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
