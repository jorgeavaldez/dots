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

The Android installer verifies that it is running in Termux, installs only the native bootstrap and Android-integration packages with `pkg`, then links the shared shell, tmux, Starship, Jujutsu, and Git configuration. Termux's native mise package manages the language toolchains and portable CLI tools declared in `mise/config.android.toml`, which is linked as `~/.config/mise/config.toml`. Existing files are preserved unless you explicitly run `./install.android.sh --force`.

Android uses Bionic rather than glibc. Bionic directly recognizes `en_US.UTF-8`, so no locale package or `locale-gen` step is needed. The Android mise config selects musl assets and manages Node.js, Python, Go, Rust, pnpm, Neovim, tmux, Starship, Zoxide, ripgrep, fd, eza, jq, delta, Jujutsu, and Prettier. Only the shell, build prerequisites, Git/SSH, mise itself, terminfo tooling, and Termux API integration are installed through `pkg`.

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
