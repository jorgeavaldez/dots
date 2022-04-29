echo "setting PATH"

export PATH="/usr/local/opt/node@14/bin:$PATH"
export PATH="/Users/jorge/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.poetry/bin:$PATH"
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
export PATH="$PATH:/Users/jorge/.foundry/bin"

export NODE_PATH="/usr/local/bin"

. "$HOME/.cargo/env"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/jorge/google-cloud-sdk/path.bash.inc' ]; then . '/Users/jorge/google-cloud-sdk/path.bash.inc'; fi

echo "PATH set"
