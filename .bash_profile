eval "$(/opt/homebrew/bin/brew shellenv)"
source ~/dots/scripts/prelude.sh
source ~/dots/scripts/brew.sh
source ~/dots/scripts/aliases.sh
source ~/dots/scripts/path.sh

if [ -f '~/dots/scripts/private.sh' ]; then . '~/dots/scripts/private.sh'; fi

echo ""
echo ""
fortune
echo ""
echo ""
