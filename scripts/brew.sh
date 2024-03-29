function install-brew() {
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

function load-bash-completion() {
  if [ -f $(brew --prefix)/etc/bash_completion ]; then
    source $(brew --prefix)/etc/bash_completion
  fi
}

function load-z() {
  [ -f $(brew --prefix)/etc/profile.d/z.sh ] && source $(brew --prefix)/etc/profile.d/z.sh
}

function load-fzf() {
  [ -f ~/.fzf.bash ] && source ~/.fzf.bash
}

function load-asdf() {
  [ -f $(brew --prefix asdf)/asdf.sh ] && source $(brew --prefix asdf)/asdf.sh
}

function load-spacemacs() {
  [ ! -d ~/.emacs.d ] && git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
}

function load-tpm() {
  [ ! -d ~/.tmux/plugins/tpm ] && git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
}

function load-starship() {
  command -v starship 2>&1 >/dev/null && eval "$(starship init bash)" || install-packages
}

function load-nvm() {
  [ ! -d ~/.nvm ] && mkdir ~/.nvm

  [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$(brew --prefix)/opt/nvm/nvm.sh"
  [ -s "$(brew --prefix)/opt/nvm/etc/bash_completion" ] && . "$(brew --prefix)/opt/nvm/etc/bash_completion"

  export NVM_DIR="$HOME/.nvm"
}

function install-packages() {
  brew bundle --global check >/dev/null

  if [ ! $? -eq 0 ]; then
    brew bundle --global
  fi
}

# TODO: move this to prelude
function create-bash-profile() {
  if [ ! -f ~/.bash_profile ]; then
    echo "source ~/.bashrc" >>~/.bash_profile
  fi
}

# if dne brew; then
#   install-brew
# else
#   # install-packages
#   load-bash-completion
#   load-z > /dev/null
#   load-fzf
#   load-asdf
#   load-spacemacs
#   load-tpm
#   load-starship
#   # load-nvm
# fi

# install-packages
load-bash-completion
load-z >/dev/null
load-fzf
# load-asdf
# load-spacemacs
load-tpm
load-starship
