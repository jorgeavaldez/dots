# dots

my dotfiles

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
- `git/config` → `~/.gitconfig`

On macOS and Linux (excluding Termux), it also links `vicinae/` into Vicinae's config directory and seeds a local settings file on fresh installs. On macOS it stages Rectangle's Spectacle-style shortcut preset. Existing Vicinae settings and pending Rectangle imports are preserved even with `--force`. See [Vicinae setup](vicinae/README.md) for app installation, existing-config imports, macOS permissions/login setup, and the additional KDE Plasma Wayland steps.

It also downloads the latest WezTerm terminfo definitions from upstream and installs them into `~/.terminfo` so tools like `less` work when `TERM=wezterm`.

On Linux outside Termux, interactive Zsh shells start or reuse `keychain` and may request the SSH key passphrase. All Zsh sessions, including non-interactive SSH commands, reuse that unlocked agent until the machine or agent restarts.

## Termux on Android

Install the Termux and Termux:API apps from the same source, configure SSH, and clone this repository to the path expected by the shared shell files:

```bash
git clone git@github.com:jorgeavaldez/dots.git ~/dots
cd ~/dots
./install.android.sh
```

The Android installer supports ARM64 Termux devices. It installs the native packages listed in `termux/packages.txt`, installs the npm packages in `termux/npm-packages.txt`, installs Herdr through its official installer, downloads the latest ARM64 musl Jujutsu and fnox releases, and links the shared shell, tmux, Starship, Jujutsu, and Git configuration. Pi is installed through its officially supported Termux setup on native Termux Node.js. Existing dotfile destinations are preserved unless you explicitly run `./install.android.sh --force`.

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
