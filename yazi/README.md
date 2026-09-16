# Yazi

`install.sh` links individual config files into `~/.config/yazi/`. General
settings, the Catppuccin light/dark theme, and the package manifest are shared.
macOS uses `macos/keymap.toml`; Linux and `install.android.sh` use `keymap.toml`.
These are complete alternative keymaps, not overlays, so shared binding changes
must be made in both.

Downloaded `plugins/` and `flavors/` stay in `~/.config/yazi/`, outside dots.
After installing Yazi and linking the configs on a new machine, run:

```sh
ya pkg install
```

The shared manifest includes Clippy, but only the macOS keymap invokes it.
On macOS, also install its executable:

```sh
brew install clippy
```

## Bindings

- All platforms: `g?` opens help.
- macOS: `y` performs the normal Yazi yank, then copies actual files to the system
  clipboard using Clippy. `gr` reveals a file in Finder.
- Linux/Termux: `y` retains the default internal yank; `gr` is unbound.

## Linux setup later

TODO: add file clipboard and file-manager reveal bindings for Linux after
choosing the target desktop/file manager and Wayland or X11 clipboard backend.
Copying paths as text is not equivalent to copying file objects: test pasting
files in the target file manager. Keep macOS commands out of the shared keymap
and preserve normal Yazi yank behavior. Use a Linux-specific keymap if those
bindings would not work on Termux.
