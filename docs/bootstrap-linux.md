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
The WezTerm terminfo download needs network access. Termux uses the same
bootstrap with a native prerequisite seed and a small Android mise overlay;
see [the Termux guide](../README.md#termux-on-android) for its bounded tool scope.

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

## Desktop smoke check

The automated tests do not launch WezTerm or exercise a desktop clipboard.
After bootstrap, fully quit WezTerm and reopen it from the desktop launcher
(not from an already configured terminal). Confirm it starts Nu and run:

```nu
$nu.current-exe
which mise nu
$env.SHELL
```

Nu should be the running shell, mise and Nu should resolve, and `SHELL` should
point to Nu. Open a new tmux/Zellij session to check new panes also start Nu.
For a clipboard round-trip, run the following **only if replacing your current
clipboard is okay**:

```nu
"dots linux check ✓" | pbcopy
pbpaste
```

The pasted text should match. This checks the real Wayland/X11 connection;
a test double cannot verify desktop launch or clipboard behavior.

## Integration tests

```sh
export NU_BIN=/absolute/path/to/nu
export FNOX_BIN=/absolute/path/to/fnox
export AGE_KEYGEN_BIN=/absolute/path/to/age-keygen
export ZOXIDE_BIN=/absolute/path/to/zoxide
export TMPDIR=/existing/scratch/directory
"$NU_BIN" --no-config-file tests/run.nu
```

Tests run on Linux with isolated HOME, XDG directories and temporary files.
Nu, fnox activation, zoxide generation, symlinks and terminfo compilation are
real; only the mise installation/resolution boundary is substituted to avoid
bulk tool installation. The real WezTerm terminfo is downloaded. Set the required
tool paths, including age-keygen, and have `tic` available. Missing tools fail
explicitly. See [the Nu test guide](test-nushell.md) for the full suite. These tests exercise the
shared Linux path, not separate Arch/Debian virtual machines or native
Windows/macOS execution.

For focused Termux coverage with the same isolated fixtures, run
`"$NU_BIN" --no-config-file tests/run.nu --filter android` with either native or
musl Nu and the tool paths above. The socket fixture additionally needs `python3`;
it binds/closes a synthetic Unix socket, never a real agent. Clipboard commands
are test doubles, not Android API interactions. A musl Nu run of the full Linux
suite on Termux fails DNS at its real terminfo download, as does a normal HTTPS
`http get` in musl Nu 0.116.0. Android runtime therefore uses native pkg Nu,
registered through mise's narrow path alias; native Nu's HTTP probe succeeds.
