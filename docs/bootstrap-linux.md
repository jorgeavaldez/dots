# Linux Nu bootstrap

Arch and Debian use the same distro-independent path:

```sh
nu --no-config-file bootstrap.nu --dry-run
nu --no-config-file bootstrap.nu
```

Have mise, Nu and system prerequisites installed first, including the build
requirements of the selected mise tools and `tic` for terminfo. The bootstrap
does not detect Linux package managers, install system packages, or install
mise on Linux. It does install the tools declared in the shared mise config.
The WezTerm terminfo download needs network access. Termux is explicitly
rejected; keep using `install.android.sh` there.

Configuration follows `XDG_CONFIG_HOME` (default `~/.config`). Existing mise,
Starship and Yazi overrides are respected. In addition to Nu, mise, Git,
WezTerm, jj and herdr, bootstrap connects:

- Starship configuration only; it does not activate a prompt.
- Yazi's four managed TOML files, not the directory. Plugins and flavors stay
  local. macOS uses its existing platform-specific keymap.
- `~/.tmux.conf`, `~/.vimrc` and Zellij configuration on Linux/macOS.
- Vicinae defaults through `vicinae/dots`, with a new **local** `settings.json`
  importing those defaults only when no settings file exists. Existing files
  and symlinks, including dangling ones, are preserved; add the printed imports
  manually when needed. GUI changes and databases stay outside the checkout.

No Zsh migration links are created. The checkout's `.ignore` remains
checkout-local: its rules expose this repository's dotfiles to search tools,
not general home-directory preferences. The system login shell and Neovim
installation remain unchanged.

Preflight checks all managed links before installation. Existing files get
`.before-dots-<uuid>` backups; Git uses `.gitconfig.local`. Directory conflicts
and an occupied Git backup abort instead of deleting local state. Already
connected links are left alone on reruns.

## Integration tests

```sh
NU_BIN=/absolute/path/to/nu \
FNOX_BIN=/absolute/path/to/fnox \
ZOXIDE_BIN=/absolute/path/to/zoxide \
python3 -m unittest discover -s tests -p test_bootstrap.py -v
```

Tests run on Linux with isolated HOME, XDG directories and temporary files.
Nu, fnox activation, zoxide generation, symlinks and terminfo compilation are
real; only the mise installation/resolution boundary is substituted to avoid
bulk tool installation. The real WezTerm terminfo is downloaded. Set all three
binary paths to avoid skips, and have `tic` available. These tests exercise the
shared Linux path, not separate Arch/Debian virtual machines or native
Windows/macOS execution.
