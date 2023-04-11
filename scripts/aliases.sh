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

function alias-emacs() {
  alias e="emacsclient -c -n -a ''"
  alias emacs="emacsclient -c -n -a ''"
  alias space="emacsclient -c -n -a ''"
  alias et="emacsclient -t -a ''"
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
alias-emacs
