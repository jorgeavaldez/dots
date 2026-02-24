# Minimal login-shell setup.
# Keep this file lean so GUI-launched apps (for example, Neovide) get the
# essential environment without pulling in interactive shell behavior.

if [[ -f "$HOME/dots/zsh/env.zsh" ]]; then
    source "$HOME/dots/zsh/env.zsh"
fi

if [[ -f "$HOME/dots/zsh/path.zsh" ]]; then
    source "$HOME/dots/zsh/path.zsh"
fi

if [[ -f "$HOME/dots/zsh/mise.zsh" ]]; then
    source "$HOME/dots/zsh/mise.zsh"
fi
