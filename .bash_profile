# Path to the bash it configuration
# export BASH_IT="/Users/jorgev/.bash_it"

# Lock and Load a custom theme file
# location /.bash_it/themes/
export BASH_IT_THEME='minimal'

# (Advanced): Change this to the name of your remote repo if you
# cloned bash-it with a remote other than origin such as `bash-it`.
# export BASH_IT_REMOTE='bash-it'

# Your place for hosting Git repos. I use this for private repos.
export GIT_HOSTING='git@git.domain.com'

# Don't check mail when opening terminal.
unset MAILCHECK

# Change this to your console based IRC client of choice.
export IRC_CLIENT='irssi'

# Set this to the command you use for todo.txt-cli
export TODO="t"

# Set this to false to turn off version control status checking within the prompt for all themes
export SCM_CHECK=true

# Set Xterm/screen/Tmux title with only a short hostname.
# Uncomment this (or set SHORT_HOSTNAME to something else),
# Will otherwise fall back on $HOSTNAME.
#export SHORT_HOSTNAME=$(hostname -s)

# Set Xterm/screen/Tmux title with only a short username.
# Uncomment this (or set SHORT_USER to something else),
# Will otherwise fall back on $USER.
#export SHORT_USER=${USER:0:8}

# Set Xterm/screen/Tmux title with shortened command and directory.
# Uncomment this to set.
#export SHORT_TERM_LINE=true

# Set vcprompt executable path for scm advance info in prompt (demula theme)
# https://github.com/djl/vcprompt
#export VCPROMPT_EXECUTABLE=~/.vcprompt/bin/vcprompt

# (Advanced): Uncomment this to make Bash-it reload itself automatically
# after enabling or disabling aliases, plugins, and completions.
# export BASH_IT_AUTOMATIC_RELOAD_AFTER_CONFIG_CHANGE=1

export PATH=~/.local/bin:$PATH
export PATH=/usr/local/opt/python@2/bin:$PATH
export WORKON_HOME=~/envs
export AWS_DEFAULT_REGION="us-east-1"

export GOPATH=~/proj/go
export PATH=${GOPATH//://bin:}/bin:$PATH

export EDITOR="emacsclient -t -a ''"
export TERM=xterm-256color

# clean docker environment
function dockerHousekeeping() {
	echo "🐳 H A U S K E E P I N G 🐳"
	echo ''

	# remove stopped containers
	echo 'Removing stopped containers...'
	docker rm $( docker ps -q -f status=exited)

  docker container prune

	# remove dangling images
	echo 'Removing dangling images...'
	docker rmi $( docker images -q -f dangling=true)

  echo "Done!"
}

# such secure, do all the security
# this is replacing ssh-agent i think?
# export GPG_TTY="$(tty)"
# export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
# gpgconf --launch gpg-agent

# git shouldn't hurt
alias add="git add"
alias commit="git commit -S -m"
alias psh="git push"

# directory aliases
alias work="cd ~/proj"
alias proj="cd ~/proj"
alias scratch="cd ~/proj/scratch"

# docker aliases
alias dhk="dockerHousekeeping"

# run good editor
alias e="emacsclient -c -n -a ''"
alias emacs="emacsclient -c -n -a ''"
alias space="emacsclient -c -n -a ''"
alias et="emacsclient -t -a ''"

# duh
alias whales?="docker ps"

# remove pyc files
alias pyc="find . -name \*.pyc -delete"

alias diffx="git status --porcelain | grep -v package-lock.json | cut -b 4- | xargs git diff"

# restart gpg agent since that shit will just bork
function reload-gpg-agent() {
    gpgconf --kill gpg-agent
    gpg-agent --daemon
}

# Load Bash It
# source "$BASH_IT"/bash_it.sh
# source /usr/local/bin/virtualenvwrapper.sh

alias l="ls -ltah"

# load bash-completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

# load Z
. `brew --prefix`/etc/profile.d/z.sh

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
source ~/.profile

function startRoutine() {
    clear
    echo ""
    fortune
    echo ""
    echo ""
}

startRoutine
