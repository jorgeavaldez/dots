if [ "$OSTYPE" == "darwin" ]; then
    export BASH_SILENCE_DEPRECATION_WARNING=1
fi

# export PATH="/usr/local/sbin:$PATH"
export PATH=~/.local/bin:$PATH
export WORKON_HOME=~/envs

# go
export GOPATH=~/proj/go
export PATH=${GOPATH//://bin:}/bin:$PATH


export EDITOR="nvim"
export CLICOLOR=1
export BAT_THEME="ansi"
# export TERM=xterm-256color

if [ "$OSTYPE" == "linux-gnu" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
    export ANDROID_HOME="/home/jorge/Android/Sdk"
    export ANDROID_SDK_ROOT="/home/jorge/Android/Sdk"
fi

export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH="${JAVA_HOME}/bin:${PATH}"

# export PATH="/Users/jorge/Library/Python/3.9/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH=$BUN_INSTALL/bin:$PATH

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

jdk() {
  version=$1
  export JAVA_HOME=$(/usr/libexec/java_home -v"$version")
  # java -version
}

# export PS4='+ $EPOCHREALTIME\011 ' # used for debugging with set -x
# set -x

# Set things to use vi key bindings
set -o vi
set editing-mode vi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jorge/google-cloud-sdk/completion.bash.inc' ]; then . '/Users/jorge/google-cloud-sdk/completion.bash.inc'; fi

function dne() {
  ! cmd_loc="$(type -p "$1")" || [[ -z $cmd_loc ]]
}

function symlink-configurations() {
  ln -s ~/dots/.bashrc ~/.bashrc 2>/dev/null
  ln -s ~/dots/.bash_profile ~/.bash_profile 2>/dev/null
  ln -s ~/dots/Brewfile ~/.Brewfile 2>/dev/null
  ln -s ~/dots/.tmux.conf ~/.tmux.conf 2>/dev/null
  ln -s ~/dots/.spacemacs ~/.spacemacs 2>/dev/null
  ln -s ~/dots/.vimrc ~/.vimrc 2>/dev/null

  [ ! -d ~/.config/ ] && mkdir ~/.config/ 2>/dev/null
  [ -d ~/.config/ ] && ln -s ~/dots/starship.toml ~/.config/starship.toml 2>/dev/null
  [ ! -d ~/.config/wezterm/ ] && ln -s ~/dots/wezterm ~/.config 2>/dev/null
}

symlink-configurations
