# Shared mise activation for login and interactive shells.

if [[ -n "${DOTS_ZSH_MISE_LOADED:-}" ]]; then
    return 0
fi
DOTS_ZSH_MISE_LOADED=1

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
