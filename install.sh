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

# Migrate legacy ~/.config/mise directory layout (directory + config.toml file)
# to a directory symlink pointing at $DOTS_DIR/mise.
prepare_mise_dir() {
    local src_dir="$DOTS_DIR/mise"
    local src_config="$src_dir/config.toml"
    local dest_dir="$HOME/.config/mise"
    local dest_config="$dest_dir/config.toml"

    if [ -d "$dest_dir" ] && [ ! -L "$dest_dir" ]; then
        local extra_entry
        extra_entry="$(find "$dest_dir" -mindepth 1 -maxdepth 1 ! -name "config.toml" -print -quit)"

        if [ -n "$extra_entry" ] && [ "$FORCE" != true ]; then
            echo "!! Conflict: $dest_dir contains files other than config.toml"
            echo "   First unexpected entry: $extra_entry"
            echo ""
            echo "   Use --force to overwrite."
            exit 1
        fi

        if [ -f "$dest_config" ] && [ ! -L "$dest_config" ] && [ "$FORCE" != true ] && ! cmp -s "$dest_config" "$src_config"; then
            echo "!! Conflict: $dest_config differs from $src_config"
            echo "   Differences (existing → new):"
            diff --color=auto -u "$dest_config" "$src_config" | sed 's/^/   /'
            echo ""
            echo "   Use --force to overwrite."
            exit 1
        fi

        rm -rf "$dest_dir"
    fi
}

install_wezterm_terminfo() {
    local terminfo_url="https://raw.githubusercontent.com/wezterm/wezterm/main/termwiz/data/wezterm.terminfo"
    local terminfo_tmp

    if ! command -v curl >/dev/null 2>&1; then
        echo "!! Warning: curl not found; skipping WezTerm terminfo install"
        return 0
    fi

    if ! command -v tic >/dev/null 2>&1; then
        echo "!! Warning: tic not found; skipping WezTerm terminfo install"
        return 0
    fi

    terminfo_tmp="$(mktemp)"
    if ! curl -fsSL -o "$terminfo_tmp" "$terminfo_url"; then
        rm -f "$terminfo_tmp"
        echo "!! Failed to download WezTerm terminfo definitions"
        exit 1
    fi

    if ! tic -x -o "$HOME/.terminfo" "$terminfo_tmp"; then
        rm -f "$terminfo_tmp"
        echo "!! Failed to install WezTerm terminfo definitions"
        exit 1
    fi

    rm -f "$terminfo_tmp"
}

# Create parent directories if needed
mkdir -p ~/.config/jj
mkdir -p ~/.config/herdr
mkdir -p ~/.config/zellij
mkdir -p ~/.config/yazi

prepare_mise_dir

# Symlink dotfiles
safe_link "$DOTS_DIR/.zshenv" ~/.zshenv
safe_link "$DOTS_DIR/.zshrc" ~/.zshrc
safe_link "$DOTS_DIR/.zprofile" ~/.zprofile
safe_link "$DOTS_DIR/.tmux.conf" ~/.tmux.conf
safe_link "$DOTS_DIR/starship.toml" ~/.config/starship.toml
safe_link_dir "$DOTS_DIR/wezterm" ~/.config/wezterm
safe_link_dir "$DOTS_DIR/mise" ~/.config/mise
safe_link "$DOTS_DIR/jj/config.toml" ~/.config/jj/config.toml
safe_link "$DOTS_DIR/herdr/config.toml" ~/.config/herdr/config.toml
safe_link "$DOTS_DIR/zellij/config.kdl" ~/.config/zellij/config.kdl
safe_link "$DOTS_DIR/git/config" ~/.gitconfig

# Link config files only; downloaded Yazi plugins/flavors stay outside dots.
safe_link "$DOTS_DIR/yazi/yazi.toml" ~/.config/yazi/yazi.toml
safe_link "$DOTS_DIR/yazi/theme.toml" ~/.config/yazi/theme.toml
safe_link "$DOTS_DIR/yazi/package.toml" ~/.config/yazi/package.toml
if [ "$(uname -s)" = Darwin ]; then
    safe_link "$DOTS_DIR/yazi/macos/keymap.toml" ~/.config/yazi/keymap.toml
else
    safe_link "$DOTS_DIR/yazi/keymap.toml" ~/.config/yazi/keymap.toml
fi

# Vicinae writes GUI changes to settings.json; import tracked defaults instead of
# symlinking that writable file (or any clipboard/snippet databases) into dots.
case "$(uname -s)" in
    Darwin | Linux)
        if [ -z "${TERMUX_VERSION:-}" ] && [[ "${PREFIX:-}" != *com.termux* ]]; then
            vicinae_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/vicinae"
            mkdir -p "$vicinae_config_dir" || exit 1
            safe_link_dir "$DOTS_DIR/vicinae" "$vicinae_config_dir/dots"

            vicinae_imports='"dots/settings.json"'
            if [ "$(uname -s)" = Darwin ]; then
                vicinae_imports+=', "dots/macos.json"'
            fi

            if [ ! -e "$vicinae_config_dir/settings.json" ] && [ ! -L "$vicinae_config_dir/settings.json" ]; then
                printf '{\n    "imports": [%s]\n}\n' "$vicinae_imports" >"$vicinae_config_dir/settings.json" || exit 1
            else
                echo "Vicinae: preserved $vicinae_config_dir/settings.json (including with --force)."
                echo "Ensure its imports array includes: $vicinae_imports"
            fi

            if [ "$(uname -s)" = Darwin ]; then
                # Rectangle consumes and renames this file on its next launch.
                # Copy it, never symlink it or replace the live preference plist.
                rectangle_config_dir="$HOME/Library/Application Support/Rectangle"
                mkdir -p "$rectangle_config_dir" || exit 1
                if [ ! -e "$rectangle_config_dir/RectangleConfig.json" ] && [ ! -L "$rectangle_config_dir/RectangleConfig.json" ]; then
                    cp "$DOTS_DIR/vicinae/RectangleConfig.json" "$rectangle_config_dir/RectangleConfig.json" || exit 1
                else
                    echo "Rectangle: pending import preserved; import vicinae/RectangleConfig.json manually if needed."
                fi
                echo "Quit Raycast before starting Vicinae and restarting Rectangle. See vicinae/README.md for permissions and login setup."
            else
                echo "KDE Plasma: import vicinae/kde.kksrc and configure Vicinae shortcuts/startup as described in vicinae/README.md."
            fi
        fi
        ;;
esac

install_wezterm_terminfo

echo "Dotfiles symlinked!"
