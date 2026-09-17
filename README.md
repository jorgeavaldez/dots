# dots

my dotfiles

## Nushell (Windows and macOS)

With Nushell, mise, and zoxide installed through your existing package setup,
use this bootstrap to connect their configuration. It does not install, upgrade,
or move programs between mise, Homebrew, WinGet, or other package managers.
Your existing Zsh/macOS setup and WezTerm installation stay as they are.

Run the same installer on either platform from `~/dots`:

```nu
nu --no-config-file bootstrap.nu --dry-run
nu --no-config-file bootstrap.nu
```

This replaces the Windows-only `bootstrap.windows.nu` and its package-install
step. There is no separate Nu tool/version list: `mise/config.toml` remains the
existing shared mise configuration. The installer never reloads Nu or changes
your login/default shell. On your Mac, just run `nu` whenever you want to try it.

Individual files are linked, not the whole Nushell config directory:

| Shared source | Destination |
| --- | --- |
| `mise/config.toml` | `~/.config/mise/config.toml` by default |
| `nushell/env.nu` | `$nu.env-path` |
| `nushell/config.nu` | `$nu.config-path` |

Nu supplies its platform-specific startup paths: normally `%APPDATA%/nushell` on
Windows and `~/Library/Application Support/nushell` on macOS. Its XDG config
override is respected, as are mise's `MISE_GLOBAL_CONFIG_FILE`, `MISE_CONFIG_DIR`,
and `XDG_CONFIG_HOME`. Existing files (including the old dots source-line loader)
are moved to sibling `.before-dots-<uuid>` backups before linking. Correct links
are left alone, including an existing mise directory symlink from `install.sh`.

Nu history stays local. `nushell/env.nu` regenerates mise's session-dependent
integration in `$nu.cache-dir`. The bootstrap generates zoxide's static integration
at `$nu.data-dir/zoxide.nu`; startup imports it without resolving or running
zoxide again. Rerun the bootstrap after upgrading zoxide to refresh that script.
Generated scripts and zoxide's history database stay outside dots.
`l` is `ls --all --long`: hidden entries,
human-readable sizes, and all metadata Nu provides on the current platform.
It is not an exact GNU `ls -lash` clone (for example, no allocated-block column).

The installer also connects `wezterm/` using a Windows directory junction or a
macOS symlink. Conflicting directory destinations stop it before any changes.
Windows **file** symlinks require Developer Mode or an elevated terminal; the
installer creates each link before moving its old config aside.

### Windows notes

The shared WezTerm config already starts `nu.exe` on Windows and disables its SSH
agent socket override so Windows OpenSSH can use 1Password. It leaves macOS's
shell choice alone. In an existing Windows Nu pane, clear an old override with
`hide-env SSH_AUTH_SOCK`, or restart WezTerm when convenient.

Configure Git locally to use Windows OpenSSH when using the 1Password agent:

```nu
git config --global core.sshCommand C:/Windows/System32/OpenSSH/ssh.exe
```

Keep that machine setting outside the shared `git/config`. This bootstrap does
not link the Git, jj, or Zsh configurations. The existing jj config requires
additional pager/editor tools and will be adapted separately.

Neovim's Windows config belongs in `%LOCALAPPDATA%/nvim` (`:echo stdpath('config')`
shows the actual path). Its config is maintained separately from this repo. If
`~/.config/nvim/init.lua` exists, the bootstrap also links `%LOCALAPPDATA%/nvim`
to that checkout. It does not install plugins or copy `.vimrc`.

## install

```bash
git clone git@github.com:jorgeavaldez/dots.git ~/dots/
cd ~/dots
./install.sh
```

If a file already exists at the destination and isn't already symlinked correctly, the script will stop and show the differences so you can review them. To overwrite anyway:

```bash
./install.sh --force
```

This will symlink:
- `.zshenv` → `~/.zshenv`
- `.zshrc` → `~/.zshrc`
- `.zprofile` → `~/.zprofile`
- `.tmux.conf` → `~/.tmux.conf`
- `opencode.json` → `~/.config/opencode/opencode.json`
- `starship.toml` → `~/.config/starship.toml`
- `wezterm/` → `~/.config/wezterm`
- `mise/` → `~/.config/mise`
- `jj/config.toml` → `~/.config/jj/config.toml`
- `zellij/config.kdl` → `~/.config/zellij/config.kdl`
- `yazi/` config files → `~/.config/yazi/` (macOS-specific keymap on macOS)
- `git/config` → `~/.gitconfig`

On macOS and Linux (excluding Termux), it also links `vicinae/` into Vicinae's config directory and seeds a local settings file on fresh installs. On macOS it stages Rectangle's Spectacle-style shortcut preset. Existing Vicinae settings and pending Rectangle imports are preserved even with `--force`. See [Vicinae setup](vicinae/README.md) for app installation, existing-config imports, macOS permissions/login setup, and the additional KDE Plasma Wayland steps.

See [Yazi setup](yazi/README.md) for installing its theme and macOS clipboard dependencies and the planned Linux clipboard/reveal bindings. Downloaded Yazi packages stay outside this repository.

It also downloads the latest WezTerm terminfo definitions from upstream and installs them into `~/.terminfo` so tools like `less` work when `TERM=wezterm`.

On Linux outside Termux, interactive Zsh shells start or reuse `keychain` and may request the SSH key passphrase. All Zsh sessions, including non-interactive SSH commands, reuse that unlocked agent until the machine or agent restarts.

## Termux on Android

Install the Termux and Termux:API apps from the same source, configure SSH, and clone this repository to the path expected by the shared shell files:

```bash
git clone git@github.com:jorgeavaldez/dots.git ~/dots
cd ~/dots
./install.android.sh
```

The Android installer supports ARM64 Termux devices. It installs the native packages listed in `termux/packages.txt`, installs the npm packages in `termux/npm-packages.txt`, installs Herdr through its official installer, downloads the latest ARM64 musl Jujutsu and fnox releases, and links the shared shell, tmux, Starship, Jujutsu, Git, and Yazi configuration. Pi is installed through its officially supported Termux setup on native Termux Node.js. Existing dotfile destinations are preserved unless you explicitly run `./install.android.sh --force`.

fnox is installed at `~/.local/bin/fnox` after verifying the archive's SHA-256 against GitHub release metadata and checking that the binary runs. Its static musl build runs directly in Termux without compiling Rust. The installer does not configure secrets or activate automatic secret loading.

The installer deliberately does not install or configure mise, glibc compatibility, a PRoot Linux distribution, or managed language toolchains. It installs the small `proot` package only for the Jujutsu shared-storage wrapper described below. Android's Bionic libc directly recognizes `en_US.UTF-8`, so no locale package or `locale-gen` step is needed. On Termux, `termux-services` owns a stable SSH agent and interactive shells use `keychain` to load `~/.ssh/id_ed25519`; non-interactive Zsh sessions reuse the same unlocked agent.

### Jujutsu on Android shared storage

Android shared storage does not support the file locks required by Jujutsu's `.jj` metadata. The Android installer therefore puts the real binary at `~/.local/libexec/jj` and installs a wrapper as the normal `~/.local/bin/jj` command.

Private-storage repositories run the real binary directly. For a repository under `/storage/emulated`, initialize its private Jujutsu metadata with:

```bash
cd /storage/emulated/0/path/to/repository
jj android init
```

The wrapper keeps working files and the colocated `.git` repository on shared storage. It stores `.jj` under `~/.local/share/jj-android/workspaces` and exposes it through PRoot only while `jj` runs. It also matches the PRoot process identity to the shared filesystem owner so Jujutsu trusts Git remote configuration. Normal subcommands and flags continue to use the same `jj` command. Unsafe `jj git init` calls on shared storage stop with the correct bootstrap instructions.

Back up `~/.local/share/jj-android` with the rest of the Termux home. If that private state is lost, Jujutsu operations and unnamed history may not be recoverable from the shared Git repository.

## shell formatting

Shell files are formatted with `shfmt` (installed via `mise`).

```bash
make format
```

Check formatting without modifying files:

```bash
make lint
# or
make check
```

See which files are included:

```bash
make shell-files
```
