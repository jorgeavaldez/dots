# Minimal login-shell setup.
# Keep this file lean so GUI-launched apps (for example, Neovide) get the
# essential environment without pulling in interactive shell behavior.

if [[ -f "$HOME/dots/zsh/env.zsh" ]]; then
    source "$HOME/dots/zsh/env.zsh" || true
fi

if [[ -f "$HOME/dots/zsh/path.zsh" ]]; then
    source "$HOME/dots/zsh/path.zsh" || true
fi

if [[ -f "$HOME/dots/zsh/mise.zsh" ]]; then
    source "$HOME/dots/zsh/mise.zsh" || true
fi

if [[ -f "$HOME/proj/werk/.shellrc" ]]; then
    source "$HOME/proj/werk/.shellrc" || true
fi
