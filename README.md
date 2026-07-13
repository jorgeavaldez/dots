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
- `.zshrc` → `~/.zshrc`
- `.zprofile` → `~/.zprofile`
- `.tmux.conf` → `~/.tmux.conf`
- `opencode.json` → `~/.config/opencode/opencode.json`
- `starship.toml` → `~/.config/starship.toml`
- `wezterm/` → `~/.config/wezterm`
- `mise/` → `~/.config/mise`
- `jj/config.toml` → `~/.config/jj/config.toml`
- `git/config` → `~/.gitconfig`

It also downloads the latest WezTerm terminfo definitions from upstream and installs them into `~/.terminfo` so tools like `less` work when `TERM=wezterm`.

## Termux on Android

Install the Termux and Termux:API apps from the same source, configure SSH, and clone this repository to the path expected by the shared shell files:

```bash
git clone git@github.com:jorgeavaldez/dots.git ~/dots
cd ~/dots
./install.android.sh
```

The Android installer supports ARM64 Termux devices. It installs the native packages listed in `termux/packages.txt`, installs the npm packages in `termux/npm-packages.txt`, downloads the latest ARM64 musl Jujutsu release, and links the shared shell, tmux, Starship, Jujutsu, and Git configuration. Pi is installed through its officially supported Termux setup on native Termux Node.js. Existing files are preserved unless you explicitly run `./install.android.sh --force`.

The installer deliberately does not install or configure mise, glibc compatibility, proot, or managed language toolchains. Android's Bionic libc directly recognizes `en_US.UTF-8`, so no locale package or `locale-gen` step is needed. On Termux, keychain starts or reuses an SSH agent and loads `~/.ssh/id_ed25519` when the shell starts.

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
