# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
	source /usr/share/zsh/manjaro-zsh-config
fi

# Manjaro zsh prompt
# if [[ -e /usr/share/zsh/manjaro-zsh-prompt ]]; then
#   source /usr/share/zsh/manjaro-zsh-prompt
# fi

# I like to use 1password to manage my ssh keys
# Typically i bypass this by restarting the ssh agent manually
if [[ ! -f "$SSH_AUTH_SOCK" && "$(uname)" == "Linux" ]]; then
	export SSH_AUTH_SOCK=~/.1password/agent.sock
fi

# aliases
alias l="eza -l -a -h"
alias c="clear"
alias dco="docker compose"
alias add="git add"
alias commit="git commit -m"
alias branch="git checkout -b"
alias psh="git push"
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

export EDITOR="nvim"
export BAT_THEME="ansi"
# export TERM=xterm-256color
# export CLICOLOR=1

set -o vi
# on macos i had this
#set editing-mode vi
# bindkey "^?" backward-delete-char
bindkey -v '^?' backward-delete-char
bindkey -a '^[[3~' delete-char

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

function dsquashed() {
	TARGET_BRANCH=${1:-main} && git checkout -q "$TARGET_BRANCH" && git for-each-ref refs/heads/ "--format=%(refname:short)" | while read -r branch; do mergeBase=$(git merge-base "$TARGET_BRANCH" "$branch") && [[ $(git cherry "$TARGET_BRANCH" $(git commit-tree $(git rev-parse $branch\^{tree}) -p "$mergeBase" -m _)) == "-"* ]] && git branch -D "$branch"; done
}

function deletepyc() {
	sudo find . -name "*.pyc" -exec rm -f {} \;
}

function editionuri() {
	FOUNDRY_ETH_RPC_URL=$MUMBAI_RPC_URL sol "IERC721Metadata($1).tokenURI(1)" | cut -d, -f2 | base64 --decode | jq .
}

function editionimpl() {
	FOUNDRY_ETH_RPC_URL=$MUMBAI_RPC_URL sol "GatedEditionCreator($1).editionImpl" | cut -d, -f2 | base64 --decode | jq .
}

function abiname() {
	forge inspect $1 abi | jq ".[] | select(.name | contains(\"$2\"))"
}

function gensecret() {
	python -c "import secrets; print(secrets.token_urlsafe())"
}

function invenv() {
	python -c 'import sys; print ("0" if sys.prefix == sys.base_prefix else "1")' 2>/dev/null
}

function mern() {
	date -d "$1" +"%Y-%m-%d %H:%M:%S"
}

function djm() {
	if ! invenv; then
		poetry shell
	fi

	python manage.py "$@"
}

function rmnodemodules() {
	find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +
}

function pbcopy() {
	xclip -selection clipboard
}

function stprod() {
	DB_HOST=127.0.0.1 DJANGO_SETTINGS_MODULE=stbackend.settings.production "$@"
}

function ststaging() {
	DB_HOST=127.0.0.1 DJANGO_SETTINGS_MODULE=stbackend.settings.staging "$@"
}

function bastiprod() {
	basti connect --rds-cluster drakula-production-backend-backendclusterdbcluster-ssq6tt3k6x6j --local-port 5433
}

function bastistaging() {
	basti connect --rds-cluster drakula-staging-backend-ad-backendclusterdbcluster-yfmxrpfwssii --local-port 5433
}

function rename-go-mod() {
	find . -name '*.go' -print0 |
		xargs -0 sed -i -e "s|$1|$2|"
}

function prnotes() {
	git diff origin/main | llm -m claude -s 'generate a markdown list of patch notes for a pull request describing the major changes in this patch'
}

function whichlogs() {
	awslogs groups | grep "$1.*$2/.*/application\|/copilot/.*$1.*$2"
}

function ssmdb() {
	aws secretsmanager list-secrets | jq -r --arg env "$1" '
        .SecretList[] |
        select(
            (.Name | contains("backendclusterAuroraSecret")) and
            (.Tags[] | select(.Key == "copilot-environment") | .Value == $env)
        ) |
        .ARN
    '
}

function ssmdbval() {
	aws secretsmanager get-secret-value --secret-id $(ssmdb $1) | jq '.SecretString | fromjson'
}

function draksecret() {
	environment="$1"
	var_name="$2"

	if [[ "$environment" != "production" && "$environment" != "staging" ]]; then
		echo "Error: Invalid environment specified. Please use 'production' or 'staging'."
		return 1
	fi

	secret_name="/copilot/drakula/${environment}/secrets/${var_name}"

	secret_value=$(aws ssm get-parameter --name "$secret_name" --with-decryption | jq -r .Parameter.Value)
	echo "$secret_value"
}

function drakdb() {
	if [[ $1 == "development" ]]; then
		pgcli postgres://postgres:password@127.0.0.1:5432/drakula_dev
	else
		pgcli postgres://postgres:$(ssmdbval $1 | jq -r .password)@127.0.0.1:5432/drakula
	fi
}

function pgd() {
	pgcli postgres://postgres:password@127.0.0.1:5432/$1
}

function hpg() {
	pgcli postgres://postgres:$(op read 'op://Private/Homelab Postgresql/password')@192.168.4.98:5432
}

function secret() {
	op item list --categories 'API Credential' | rg -i $1 | awk '{print $1}' | xargs -n1 op item get --fields credential
}

function branches() {
	git for-each-ref \
		--sort=-committerdate \
		--format="%(color:blue)%(committerdate)%(color:reset) %09 %(color:yellow)%(authorname)%(color:reset) %09 %(color:green)%(refname)%(color:reset)" \
		--color=always refs/remotes | \
	rg --color=always "Jorge"
}

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"

export BUN_INSTALL="$HOME/.bun"
export FLYCTL_INSTALL="$HOME/.fly"
export GOPATH="$HOME/proj/go"

if [ -f "$HOME/bin/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/bin/google-cloud-sdk/path.zsh.inc"; fi

export PATH="${PATH}:${ANDROID_SDK_ROOT}/emulator"
export PATH="${PATH}:${ANDROID_SDK_ROOT}/platform-tools"
export PATH="${PATH}:${ANDROID_SDK_ROOT}/tools"
export PATH="${PATH}:${ANDROID_SDK_ROOT}/tools/bin"
export PATH="${JAVA_HOME}/bin:${PATH}"
export PATH="${GOPATH//://bin:}/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="${PATH}:$HOME/bin"
export PATH="$HOME/.ebcli-virtual-env/executables:${PATH}"
export PATH="${PATH}:$HOME/.foundry/bin"
export PATH="$HOME/.local/share/solana/install/active_release/bin:${PATH}"
export PATH="$BUN_INSTALL/bin:${PATH}"
export PATH="$HOME/proj/solidity-one-liners/bin:${PATH}"
export PATH="$HOME/proj/nimlsp:$PATH"
export PATH="$HOME/.nimble/bin:${PATH}"
export PATH="$HOME/.cargo/bin:${PATH}"
export PATH="$HOME/go/bin:${PATH}"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

. "$HOME/.cargo/env"

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export CLOUDSDK_DEVAPPSERVER_PYTHON="/usr/bin/python2"

__git_files () { 
    _wanted files expl 'local files' _files     
}

source "$HOME/dots/secrets.sh"

if [ -f /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
if [ -f /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

if type brew &>/dev/null; then
	FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

# this is a vscode plugin for a fuzzy search w/ ripgrep that mimics telescope in neovim
# unfortunately it doesn't like some of these shell hooks so i disable them to get a faster startup
if [[ $FIND_IT_FASTER_ACTIVE -eq 0 ]]; then
	eval "$(atuin init zsh)"
	eval "$(zoxide init zsh)"
	eval "$(mise activate zsh)"
	eval "$(starship init zsh)"
fi

# completions
autoload -Uz compinit && compinit
autoload bashcompinit && bashcompinit
if [ -f "$HOME/bin/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/bin/google-cloud-sdk/completion.zsh.inc"; fi
complete -C '/usr/local/bin/aws_completer' aws
