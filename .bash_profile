eval "$(/opt/homebrew/bin/brew shellenv)"
source ~/dots/scripts/prelude.sh
source ~/dots/scripts/brew.sh
source ~/dots/scripts/aliases.sh
source ~/dots/scripts/path.sh

clear
echo ""
echo ""
fortune
echo ""
echo ""
eval "$(/opt/homebrew/bin/brew shellenv)"

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jorge/google-cloud-sdk/completion.bash.inc' ]; then . '/Users/jorge/google-cloud-sdk/completion.bash.inc'; fi

echo "bash_profile"
