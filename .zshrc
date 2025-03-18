# Use powerline
USE_POWERLINE="true"

# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi

# Use manjaro zsh prompt
# if [[ -e /usr/share/zsh/manjaro-zsh-prompt ]]; then
#   source /usr/share/zsh/manjaro-zsh-prompt
# fi

if [[ ! -f "$SSH_AUTH_SOCK" ]]; then
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
alias e="nvim"

function kshell() {
	kubectl exec -it "$1" -- /bin/bash
}

function kscale() {
	kubectl scale deployment/$1 --replicas=$2
}

function klogs() {
    kubectl logs -f "$1" "$2"
}

export EDITOR="nvim"
export BAT_THEME="ansi"

set -o vi
bindkey -v '^?' backward-delete-char
bindkey -a '^[[3~' delete-char

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/jorge/bin/google-cloud-sdk/path.zsh.inc' ]; then . '/home/jorge/bin/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/jorge/bin/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/jorge/bin/google-cloud-sdk/completion.zsh.inc'; fi

# nnn
export NNN_PLUG='f:fzcd;o:fzopen;p:mocq;d:diffs;t:nmount;v:imgview'
export NNN_OPTS="HdeA"

function plsown() {
	sudo chown -R $USER $1
}

function reload() {
	. ~/.zshrc
}

function myip() {
	nmcli device show | grep IP4.ADDRESS | head -1 | awk '{print $2}' | rev | cut -c 4- | rev
}

function deletesquashed() {
	TARGET_BRANCH=main && git checkout -q $TARGET_BRANCH && git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch; do mergeBase=$(git merge-base $TARGET_BRANCH $branch) && [[ $(git cherry $TARGET_BRANCH $(git commit-tree $(git rev-parse $branch\^{tree}) -p $mergeBase -m _)) == "-"* ]] && git branch -D $branch; done
}

function deletestsquashed() {
	TARGET_BRANCH=staging && git checkout -q $TARGET_BRANCH && git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch; do mergeBase=$(git merge-base $TARGET_BRANCH $branch) && [[ $(git cherry $TARGET_BRANCH $(git commit-tree $(git rev-parse $branch\^{tree}) -p $mergeBase -m _)) == "-"* ]] && git branch -D $branch; done
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
	date -d $1 +"%Y-%m-%d %H:%M:%S"
}

function djm() {
	if ! invenv; then
		poetry shell;
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
	find . -name '*.go' -print0 \
	  | xargs -0 sed -i -e "s|$1|$2|"
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
	pgcli postgres://postgres:$(ssmdbval $1 | jq -r .password)@127.0.0.1:5432/drakula
}

function drakdbp() {
	pgcli postgres://postgres:$(ssmdbval $1 | jq -r .password)@127.0.0.1:5433/drakula
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

# function sstdb() {
# 	if [[ -z "${SST_RESOURCE_TenkayDB}" ]]; then
# 		echo "Error: SST_RESOURCE_TenkayDB environment variable is not set"
# 		kill $TUNNEL_PID
# 		exit 1
# 	fi
# 
# 	if ! command -v jq &> /dev/null; then
# 		echo "Error: jq is not installed but required for JSON parsing"
# 		kill $TUNNEL_PID
# 		exit 1
# 	fi
# 
# 	DB_NAME=$(echo $SST_RESOURCE_TenkayDB | jq -r '.database // ""')
# 	DB_HOST=$(echo $SST_RESOURCE_TenkayDB | jq -r '.host // ""')
# 	DB_PORT=$(echo $SST_RESOURCE_TenkayDB | jq -r '.port // ""')
# 	DB_USER=$(echo $SST_RESOURCE_TenkayDB | jq -r '.username // ""')
# 	DB_PASS=$(echo $SST_RESOURCE_TenkayDB | jq -r '.password // ""')
# 
# 	if [[ -z "$DB_NAME" || -z "$DB_HOST" || -z "$DB_PORT" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
# 		echo "Error: Missing required database connection information in SST_RESOURCE_TenkayDB"
# 		echo "Required fields: database, host, port, username, password"
# 		exit 1
# 	fi
# 
# 	PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"
# }

export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
export ANDROID_HOME="/home/jorge/Android/Sdk"
export ANDROID_SDK_ROOT="/home/jorge/Android/Sdk"

export BUN_INSTALL="$HOME/.bun"
export FLYCTL_INSTALL="/home/jorge/.fly"

export PATH="${PATH}:${ANDROID_SDK_ROOT}/emulator"
export PATH="${PATH}:${ANDROID_SDK_ROOT}/platform-tools"
export PATH="${JAVA_HOME}/bin:${PATH}"
export PATH="${PATH}:/home/jorge/bin"
export PATH="/home/jorge/.ebcli-virtual-env/executables:${PATH}"
export PATH="${PATH}:/home/jorge/.foundry/bin"
export PATH="/home/jorge/.local/share/solana/install/active_release/bin:${PATH}"
export PATH="$BUN_INSTALL/bin:${PATH}"
export PATH="/home/jorge/proj/solidity-one-liners/bin:${PATH}"
export PATH="/home/jorge/.nimble/bin:${PATH}"
export PATH="/home/jorge/.cargo/bin:${PATH}"
export PATH="/home/jorge/go/bin:${PATH}"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export CLOUDSDK_DEVAPPSERVER_PYTHON="/usr/bin/python2"

source ~/dots/secrets.sh

if [[ $FIND_IT_FASTER_ACTIVE -eq 0 ]]; then
	eval "$(atuin init zsh)"
	eval "$(zoxide init zsh)"
	eval "$(mise activate zsh)"
	eval "$(starship init zsh)"
fi

autoload -Uz compinit && compinit
autoload bashcompinit && bashcompinit
complete -C '/usr/local/bin/aws_completer' aws

# pnpm
export PNPM_HOME="/home/jorge/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# bun completions
[ -s "/home/jorge/.bun/_bun" ] && source "/home/jorge/.bun/_bun"

