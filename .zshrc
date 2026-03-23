# zmodload zsh/zprof

# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
    source /usr/share/zsh/manjaro-zsh-config
fi

# Shared login-safe environment and PATH.
if [[ -f "$HOME/dots/zsh/env.zsh" ]]; then
    source "$HOME/dots/zsh/env.zsh"
fi

if [[ -f "$HOME/dots/zsh/path.zsh" ]]; then
    source "$HOME/dots/zsh/path.zsh"
fi

if [[ -f "$HOME/dots/zsh/private.zsh" ]]; then
    source "$HOME/dots/zsh/private.zsh"
fi

# aliases
function notify() {
    local title="Notification"
    local body=""

    if [[ $# -eq 1 ]]; then
        # One parameter: treat as body with default title
        body="$1"
    elif [[ $# -eq 2 ]]; then
        # Two parameters: title and body
        title="$1"
        body="$2"
    else
        # No parameters or too many: show usage
        echo "Usage: notify [title] body"
        echo "Example: notify 'Task Complete' 'Your command finished successfully!'"
        echo "  or:  notify 'Your command finished successfully!'"
        return 1
    fi

    printf "\e]777;notify;%s;%s\e\\" "$title" "$body"
}

alias l="eza -l -a -h"
alias c="clear"
alias dco="docker compose"

# jj
alias psh="jj git push"
function commit() {
    if [[ -n "$1" ]]; then
        jj commit -m "$1"
    elif [[ ! -t 0 ]]; then
        local msg
        msg=$(cat)
        jj commit -m "$msg"
    else
        jj commit
    fi
}

if [[ -f "$HOME/dots/zsh/pr.zsh" ]]; then
    source "$HOME/dots/zsh/pr.zsh"
fi

# first non empty parent commit
alias nearestparent="jj log -r closest_parent"
# exclude head like this, negate @
# 'heads((first_ancestors(@) ~ @) & ~empty())'

function bump() {
    jj bookmark move "$(jj currbm-name)" -t @-
}

alias proj="cd ~/proj"
alias pn="pnpm"
alias n="nvim"
alias bottom="btm"
alias e="nvim"
alias ..="cd .."
alias ...="cd ../.."
alias scripts="jq .scripts package.json"
alias ezsh="nvim $HOME/.zshrc"
alias reload="source $HOME/.zshrc"
alias evim="nvim $HOME/.config/nvim/init.lua"

function mise-use-private() {
    local config_path="$HOME/.config/mise.toml"

    if [[ $# -eq 0 ]]; then
        echo "Usage: mise-use-private <tool@version> [tool@version ...]"
        echo "Example: mise-use-private npm:confluence-cli@/Users/jorge/proj/confluence-cli"
        return 1
    fi

    command mise use --path "$config_path" "$@" || return $?
    command mise install -f "$@" || return $?
    rehash
}

# export TERM=xterm-256color
# export CLICOLOR=1

set -o vi
# on macos i had this
#set editing-mode vi
# bindkey "^?" backward-delete-char
bindkey -v '^?' backward-delete-char
bindkey -a '^[[3~' delete-char

function find_local_env() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/local.env" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

function nenv() {
    local project_root
    project_root="$(find_local_env)"
    if [[ -z "$project_root" ]]; then
        echo "Error: local.env not found in current directory or any parent" >&2
        return 1
    fi
    ENV="${ENV:-local}" op run --env-file="${project_root}/local.env" --no-masking -- "$@"
}

function kshell() {
    kubectl exec -it "$1" -- /bin/bash
}

function kscale() {
    kubectl scale deployment/"$1" --replicas="$2"
}

function klogs() {
    kubectl logs -f "$1" "$2"
}

function plsown() {
    sudo chown -R "$USER" "$1"
}

function myip() {
    nmcli device show | grep IP4.ADDRESS | head -1 | awk '{print $2}' | rev | cut -c 4- | rev
}

function deletepyc() {
    sudo find . -name "*.pyc" -exec rm -f {} \;
}

function gensecret() {
    python -c "import secrets; print(secrets.token_urlsafe())"
}

function mern() {
    date -d "$1" +"%Y-%m-%d %H:%M:%S"
}

function rmnodemodules() {
    find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +
}

if [[ "$(uname)" == "Linux" ]]; then
    function pbcopy() {
        xclip -selection clipboard
    }
fi

# Colima/Testcontainers configuration for macOS.
# Kept in a separate file to isolate the startup-specific logic.
if [[ -f "$HOME/dots/zsh/colima-testcontainers.zsh" ]]; then
    source "$HOME/dots/zsh/colima-testcontainers.zsh"
fi

function rename-go-mod() {
    find . -name '*.go' -print0 |
        xargs -0 sed -i -e "s|$1|$2|"
}

function pgd() {
    pgcli "postgres://postgres:password@127.0.0.1:5432/$1"
}

function hpg() {
    PGHOST="$(op read 'op://Private/homelab pgsql/server')" \
    PGPORT=5432 \
    PGUSER="$(op read 'op://Private/homelab pgsql/username')" \
    PGPASSWORD="$(op read 'op://Private/homelab pgsql/password')" \
    PGCLIENTENCODING=utf8 \
        pgcli
}

function hpgdump() {
    PGHOST="$(op read 'op://Private/homelab pgsql/server')" \
    PGPORT=5432 \
    PGUSER="$(op read 'op://Private/homelab pgsql/username')" \
    PGPASSWORD="$(op read 'op://Private/homelab pgsql/password')" \
    PGCLIENTENCODING=utf8 \
        pg_dump -Fc -f "$1" "$2"
}

function secret() {
    op item list --categories 'API Credential' | rg -i "$1" | awk '{print $1}' | xargs -n1 op item get --fields credential
}

function tellme() {
    notify-send "hey buddy" "$1"
}

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

function ktail() {
    local namespace="$1"
    if [[ -z "$namespace" ]]; then
        echo "Usage: ktail <namespace>"
        return 1
    fi

    # Ensure we kill all background tails on exit
    trap 'kill $(jobs -p) 2>/dev/null' SIGINT SIGTERM EXIT

    # Loop over all pod names in the namespace
    for pod in $(kubectl get pods -n "$namespace" --no-headers \
        -o custom-columns=":metadata.name"); do
        local logfile="${pod}.log"
        echo "Tailing logs for pod '$pod' → $logfile"
        kubectl logs -n "$namespace" -f "$pod" >"$logfile" 2>&1 &
    done

    # Wait for all background jobs (the tail processes) to exit
    wait
}

function filets() {
    date +"%Y-%m-%d_%H-%M-%S"
}

function filewts() {
    local prefix="$1"
    local extension="$2"
    echo "${prefix}_$(filets)${extension}"
}

function packagejsoncontains() {
    jq -r "
		[\"dependencies\", \"devDependencies\", \"peerDependencies\", \"optionalDependencies\", \"bundledDependencies\"] as \$sections |
		\$sections[] as \$section |
		select(has(\$section)) |
		.[\$section] | to_entries[] |
		select(.key | contains(\"${1}\")) |
		\"\(\$section): \(.key) = \(.value)\"
	" package.json
}

function fix-slop() {
    find "${1:-.}" -type f -exec perl -i -pe 's/\x{2014}/-/g; s/—/-/g; s/\xe2\x80\x91/-/g; s/\x{2011}/-/g; s/\xe2\x80\x99/'\''/g; s/\x{2019}/'\''/g' {} +
}

function pg2md() {
    awk '
      # Skip border lines
      /^\+[-+]+\+$/ { next }

      # Process separator line (convert to markdown)
      /^\|[-+|]+\|$/ {
        gsub(/[-+]+/, "---")
        print
        next
      }

      # Print all other lines (header and data)
      { print }
    ' "${1:--}"
}

function podshell() {
    POD=$(kubectl -n temporal get pods -l app=temporal-worker -o jsonpath='{.items[0].metadata.name}')
    kubectl -n temporal exec -it "$POD" -c temporal-worker -- bash
}

__git_files() {
    _wanted files expl 'local files' _files
}

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

if [[ -f "$HOME/.turso/env" ]]; then
    . "$HOME/.turso/env"
fi

if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

# this is a vscode plugin for a fuzzy search w/ ripgrep that mimics telescope in neovim
# unfortunately it doesn't like some of these shell hooks so i disable them to get a faster startup
if [[ $FIND_IT_FASTER_ACTIVE -eq 0 ]]; then
    eval "$(atuin init zsh)"
    eval "$(zoxide init zsh)"
    if [[ -f "$HOME/dots/zsh/mise.zsh" ]]; then
        source "$HOME/dots/zsh/mise.zsh"
    fi
    eval "$(starship init zsh)"
fi

# completions
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
autoload bashcompinit && bashcompinit
if [ -f "$HOME/bin/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/bin/google-cloud-sdk/completion.zsh.inc"; fi
complete -C '/usr/local/bin/aws_completer' aws
complete -o nospace -C terraform terraform

if [[ "$INSIDE_EMACS" = 'vterm' ]]; then
    # integrate w/ emacs vterm
    function vterm_printf() {
        if [ -n "$TMUX" ] &&
            { [ "${TERM%%-*}" = "tmux" ] ||
                [ "${TERM%%-*}" = "screen" ]; }; then
            # Tell tmux to pass the escape sequences through
            printf "\ePtmux;\e\e]%s\007\e\\" "$1"
        elif [ "${TERM%%-*}" = "screen" ]; then
            # GNU screen (screen, screen-256color, screen-256color-bce)
            printf "\eP\e]%s\007\e\\" "$1"
        else
            printf "\e]%s\e\\" "$1"
        fi
    }

    function vterm_cmd() {
        local vterm_elisp
        vterm_elisp=""
        while [ $# -gt 0 ]; do
            vterm_elisp="$vterm_elisp""$(printf '"%s" ' "$(printf "%s" "$1" | sed -e 's|\\|\\\\|g' -e 's|"|\\"|g')")"
            shift
        done
        vterm_printf "51;E$vterm_elisp"
    }

    function vterm_prompt_end() {
        vterm_printf "51;A$(whoami)@$(hostname):$(pwd)"
    }
    setopt PROMPT_SUBST
    PROMPT=$PROMPT'%{$(vterm_prompt_end)%}'
fi

# zprof
