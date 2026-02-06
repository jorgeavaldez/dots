#!/bin/bash

DOTS_DIR="$(cd "$(dirname "$0")" && pwd)"

FORCE=false
if [[ "$1" == "--force" ]]; then
  FORCE=true
fi

# safe_link source destination
# If destination exists and is not already a symlink to source, show diff and abort (unless --force).
safe_link() {
  local src="$1"
  local dest="$2"

  # If destination exists (file, dir, or symlink)
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    # Already points to the right place — nothing to do (resolve both to absolute paths)
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
      return 0
    fi

    if [ "$FORCE" = true ]; then
      rm -rf "$dest"
    else
      echo "!! Conflict: $dest already exists and differs from $src"
      if [ -L "$dest" ]; then
        echo "   Current symlink target: $(readlink "$dest")"
        echo "   Expected symlink target: $src"
      fi
      # Show content diff if both are readable files (resolve symlinks)
      local real_dest="$dest"
      [ -L "$dest" ] && real_dest="$(readlink -f "$dest")"
      if [ -f "$real_dest" ] && [ -f "$src" ]; then
        echo "   Differences (existing → new):"
        diff --color=auto -u "$real_dest" "$src" | sed 's/^/   /'
      fi
      echo ""
      echo "   Use --force to overwrite."
      exit 1
    fi
  fi

  ln -sf "$src" "$dest"
}

# Like safe_link but uses ln -sfn for directories
safe_link_dir() {
  local src="$1"
  local dest="$2"

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
      return 0
    fi

    if [ "$FORCE" = true ]; then
      rm -rf "$dest"
    else
      echo "!! Conflict: $dest already exists and differs from $src"
      if [ -L "$dest" ]; then
        echo "   Current symlink target: $(readlink "$dest")"
        echo "   Expected symlink target: $src"
      fi
      echo ""
      echo "   Use --force to overwrite."
      exit 1
    fi
  fi

  ln -sfn "$src" "$dest"
}

# Create parent directories if needed
mkdir -p ~/.config/opencode
mkdir -p ~/.config/jj
mkdir -p ~/.config/mise

# Symlink dotfiles
safe_link "$DOTS_DIR/.zshrc" ~/.zshrc
safe_link "$DOTS_DIR/.tmux.conf" ~/.tmux.conf
safe_link "$DOTS_DIR/opencode.json" ~/.config/opencode/opencode.json
safe_link "$DOTS_DIR/starship.toml" ~/.config/starship.toml
safe_link_dir "$DOTS_DIR/wezterm" ~/.config/wezterm
safe_link "$DOTS_DIR/config.toml" ~/.config/mise/config.toml
safe_link "$DOTS_DIR/jj/config.toml" ~/.config/jj/config.toml
safe_link "$DOTS_DIR/git/config" ~/.gitconfig

echo "Dotfiles symlinked!"
