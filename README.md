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

Android uses Bionic rather than glibc. Bionic directly recognizes `en_US.UTF-8`, so no locale package or `locale-gen` step is needed. The Android mise config manages Node.js, Python, Go, Rust, pnpm, tmux, eza, and compatible Android or static ARM64 musl builds of Starship, Zoxide, fd, and Jujutsu. Node.js, Python, and Rust are installed as standard ARM64 Linux toolchains inside a small `proot` compatibility boundary, then wrapped so they run through Termux's glibc loader; no language runtime is installed through `pkg`. Termux packages provide only the shell, build libraries, Git/SSH, mise itself, glibc compatibility, native CLI tools without compatible upstream assets, terminfo tooling, and Termux API integration.

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
