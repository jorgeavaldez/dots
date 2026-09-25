# Git Bash: expose winget links (including mise) and user commands before activation.
export PATH="$HOME/bin:$HOME/AppData/Local/Microsoft/WinGet/Links:$HOME/AppData/Local/Microsoft/WindowsApps:$PATH"
export MISE_ACTIVATE_AGGRESSIVE=true
eval "$(mise activate bash)"

# Hermes ignores global Git config and pins bare ssh -o BatchMode=yes for clones.
# Git Bash's ssh cannot use 1Password's Windows named-pipe agent. Override it
# here for Git subprocesses (including Hermes); BatchMode fails fast without it.
export GIT_SSH_COMMAND="\"$(cygpath -m "$SYSTEMROOT")/System32/OpenSSH/ssh.exe\" -o BatchMode=yes"

# Load cached global secrets once at startup (no per-prompt provider lookups).
export FNOX_CONFIG_DIR="${FNOX_CONFIG_DIR:-$HOME/.config/fnox}"
export FNOX_SHELL_OUTPUT=none
unset __FNOX_SESSION
eval "$(fnox hook-env -s bash)"
