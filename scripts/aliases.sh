function alias-misc() {
  alias l="exa -l -a -h"
  alias c="clear"
  alias chrome="open -a Google\ Chrome --args --disable-web-security --user-data-dir \"\""
  alias dco="docker-compose"
}

function alias-git() {
  alias add="git add"
  alias commit="git commit -m"
  alias psh="git push"
}

function alias-dirs() {
  alias work="cd ~/proj"
  alias proj="cd ~/proj"
  alias scratch="cd ~/proj/scratch"
}

function alias-editor() {
  alias e="nvim"
  alias n="nvim"
  alias nconf="nvim ~/.config/nvim/"
}

function reload() {
  . ~/.bashrc
}

function kshell() {
  kubectl exec -it "$1" -- /bin/bash
}


function kscale() {
  kubectl scale "deployment/$1" --replicas=$2
}


alias pn="pnpm"

alias-misc
alias-git
alias-dirs
alias-editor
