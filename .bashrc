source ~/dots/prelude
source ~/dots/aliases
source ~/dots/brew

clear
echo ""
echo ""
fortune
echo ""
echo ""

###-tns-completion-start-###
if [ -f /Users/delvaze/.tnsrc ]; then 
    source /Users/delvaze/.tnsrc 
fi
###-tns-completion-end-###
. "$HOME/.cargo/env"
