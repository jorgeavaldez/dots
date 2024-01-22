if [ -f /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
if [ -f /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
source ~/dots/scripts/prelude.sh
source ~/dots/scripts/brew.sh
source ~/dots/scripts/aliases.sh
source ~/dots/scripts/path.sh

if [ -f ~/dots/scripts/private.sh ]; then . ~/dots/scripts/private.sh; fi

echo ""
echo ""
fortune
echo ""
echo ""



[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"
