# dots

my dotfiles

## Nushell bootstrap (Windows and macOS)

Start with a copy of this repository and:

- **Windows:** Nushell installed through WinGet, with WinGet on PATH. File
  symlinks require Developer Mode or an elevated Nu terminal. The installer
  checks that permission before changing configs or installing packages; it
  does not change Windows security settings. Package installers may show UAC.
- **macOS:** Nushell and Homebrew installed. If Apple's Command Line Tools are
  missing, finish the prompted installation and rerun the bootstrap.

Run from the checkout (it does not have to be `~/dots`):

```nu
nu --no-config-file bootstrap.nu --dry-run
nu --no-config-file bootstrap.nu
```

The Nu installer installs mise if missing, connects the shared mise config,
uses its `[bootstrap.packages]` to install missing WinGet/Homebrew packages,
ensures compiler prerequisites, then installs missing `[tools]` with mise.
`mise/config.toml` is the only package/tool list. WinGet is preferred for Windows
system packages; no Scoop fallback is currently needed. Ripgrep and Carapace
are mise-managed. The Windows C++ check verifies both the compiler and Windows
SDK, and adds the Visual C++ workload when either is missing. A required reboot
stops setup with instructions to rerun afterward. On Intel Macs, bootstrap applies
those same package declarations through the installed Homebrew CLI because mise's
native Homebrew manager supports only Apple Silicon on macOS.

Use **this Nu entrypoint** for full machine setup. `mise install` alone does not
install system packages or configure compiler workloads. Bootstrap doesn't
force upgrades of already-installed system applications.

### Connected configs

| Shared source | Destination |
| --- | --- |
| `mise/config.toml` | `~/.config/mise/config.toml` by default |
| `nushell/env.nu`, `nushell/config.nu` | Nu's own startup paths |
| `wezterm/` | `~/.config/wezterm` (respects XDG on macOS) |
| `jj/config.toml` | jj's user config path; `%APPDATA%/jj/config.toml` on fresh Windows |
| `herdr/config.toml` | `%APPDATA%/herdr/config.toml` on Windows; `~/.config/herdr/config.toml` on macOS |
| `git/config`, `git/ignore` | `~/.gitconfig`, `~/.gitignore` |
| `.tmux.conf`, `zellij/config.kdl` | `~/.tmux.conf`, `~/.config/zellij/config.kdl` on macOS only |

Nu supplies its startup paths; the bootstrap respects its config-home override
and mise's `MISE_GLOBAL_CONFIG_FILE`, `MISE_CONFIG_DIR`, and `XDG_CONFIG_HOME`.
Existing non-conflicting files are preserved in sibling `.before-dots-<uuid>`
backups. Correct links are left alone, including the older mise directory link.
Conflicting directories stop setup. WezTerm uses a directory junction on Windows.
There is no file-copy fallback: edits through connected configs update dots.

Existing `~/.gitconfig` is preserved as **`~/.gitconfig.local`**, which the shared
config includes. Keep machine-local SSH/credential settings there, not in the
symlinked shared file. If both files already exist before migration, setup stops
rather than guessing how to merge them. `core.excludesfile = ~/.gitignore` uses
Git's home expansion on both platforms; `git/ignore` starts empty. Existing global
ignore contents are backed up for review, not silently copied into the repo.

The macOS bootstrap also installs WezTerm terminfo into `~/.terminfo`. WezTerm
starts Nu on both platforms; macOS Nu sets `SHELL` for tmux/Zellij child panes.
The system login shell and all Zsh startup files are unchanged. WezTerm already
bundles the configured JetBrains Mono font.

### Interactive Nu

- Vi editing, mise/zoxide, and Carapace external completions. Completion bridges
  to Bash/Zsh/Fish are disabled; aliases such as `j` and `dco` keep their expansion.
- `pbcopy` / `pbpaste` use the native macOS or Windows clipboard, preserving UTF-8
  text without adding a newline.
- `commit` accepts a message argument or piped text; no input opens jj's editor.
  `bump` moves the current bookmark to `@-` and refuses ambiguous/absent bookmarks.
- `dco` aliases `docker compose`; Docker itself is not installed.
- `BAT_THEME=ansi`; `EDITOR`/`VISUAL` default to Neovim without overriding an
  inherited editor. macOS keeps `GOPATH=~/proj/go`, Fly, and Obsidian paths.
- `l` is Nu's structured `ls --all --long`, not an exact eza clone. `reload`
  replaces the shell; temporary variables and definitions are lost.

Nu history remains local; Atuin and Starship are separate work. Bootstrap
regenerates zoxide's integration in `$nu.data-dir/zoxide.nu`; rerun it after a
zoxide upgrade. Mise's session-dependent integration is regenerated at startup.

Neovim and its config are **entirely separate**, including Windows config links.
The jj diff/merge editor expects the custom Neovim commands already installed
there. This bootstrap does not install Docker/Postgres, enroll secrets or
configure SSH authentication, migrate Yazi, or configure macOS desktop applications.
Linux and Termux remain on the existing installers below for now.

### Automatic secrets (Windows and macOS)

Bootstrap installs fnox, age, and the 1Password CLI. After opening a new Nu session,
run the one-time device setup:

```nu
secrets setup
```

This creates a separate age identity for this device and stores its private key
in Windows Credential Manager or macOS Keychain. It also creates an empty,
commented `sources.toml` template if missing. Repeating setup preserves existing
references, identity, and cache. Both `sources.toml` and the encrypted
`config.toml` stay in `~/.config/fnox/` (or `$env.FNOX_CONFIG_DIR`),
**outside dots and not symlinked**. An unrelated existing fnox config stops
enrollment rather than being overwritten.

To create only the reference template, without enrolling a device or fetching
anything, run:

```nu
secrets init
```

The command prints its path and never overwrites an existing file. Add your
variables under `[secrets]` in that **private** `sources.toml`:

```toml
[secrets]
OPENAI_API_KEY = { provider = "onepassword", value = "op://Vault/Item/credential" }
```

Enter actual values in 1Password, not this file or shell command arguments.
Enable 1Password CLI access/sign in, then fetch and encrypt the values locally:

```nu
secrets refresh
```

Refresh also updates the current Nu environment and removes cached variables whose
mappings were deleted. Repeat it after adding references or rotating keys; existing
child processes need restarting to see updates. `DOTS_AGE_IDENTITY` is reserved
for the device identity and is never exported.

New Nu sessions automatically decrypt the local cache into their environment.
Pi and other child processes inherit those variables without a wrapper or another
1Password call. Startup does not discover project fnox files, run a daemon, or
fetch missing secrets remotely. A new mapping without a cached value tells you
to run `secrets refresh`; decryption failures are reported. Nu remains usable
before enrollment. Locking 1Password does not lock the independent local cache.

For fast startup, `dots-fnox-path` beside the device config caches only fnox's
executable path, never decrypted keys. Setup and refresh update it; a missing
cache or executable is re-resolved automatically. After upgrading fnox, run
`secrets setup` to select the new executable without contacting 1Password.

To check without displaying a key, use its presence rather than its value:

```nu
$env.OPENAI_API_KEY? != null
nu --no-config-file -c '$env.OPENAI_API_KEY? != null'
```

On a second Windows machine or Mac, run `secrets setup` and `secrets refresh`
there too, and populate that device's private `sources.toml`. Actual service,
vault, item, and field references are not stored in this repository; only the
empty template is shared. If moving from the old repository-local
`fnox/sources.toml`, move it to the private fnox directory before starting a new
shell; that old repository path is now ignored. Do not share device identities
or encrypted caches. The old Zsh setup and Linux/Termux integration are unchanged.

### macOS setup and smoke test

1. Get the updated checkout onto your Mac. In your existing terminal, install
   Nushell if needed, then enter the checkout (adjust the path as appropriate):

   ```sh
   brew install nushell
   cd ~/dots
   ```

2. Preview the changes, inspect any conflicts, then run the bootstrap:

   ```sh
   nu --no-config-file bootstrap.nu --dry-run
   nu --no-config-file bootstrap.nu
   ```

   If a directory conflict is reported, inspect and preserve it before proceeding;
   don't blindly delete it. If prompted for Apple's Command Line Tools, finish
   their installation and rerun. Tool installation can take a while. Use this Nu
   entrypoint rather than `install.sh` for the migration.

3. After setup succeeds, safely close your WezTerm sessions and fully quit the
   application. Reopen it **from the Dock or Finder**, not another terminal. It
   should start Nu without an executable-not-found error; this checks that the
   launch PATH works without inheriting your old shell's environment.

4. In the new Nu pane, check the tools and shell configuration:

   ```nu
   version
   which mise jj rg carapace zoxide
   $env.SHELL
   $env.config.edit_mode
   jj config path --user
   ```

   Each tool should resolve, `SHELL` should point to Nu, and editing mode should
   be `vi`. Type `j --` and press Tab to check completions. Start fresh tmux and
   Zellij sessions and confirm their new panes also start Nu.

5. Optionally test clipboard round-tripping. **This replaces your clipboard:**

   ```nu
   "dots mac test ✓" | pbcopy
   pbpaste
   ```

   The pasted text should match, including the check mark.

6. From the checkout, repeat the dry-run. Config links should report
   **Already connected**. Rerunning the full bootstrap also checks repeat setup;
   existing system packages are skipped, while missing mise tools are installed
   and generated integrations are refreshed. Mise tools configured as `latest`
   can pick up newer releases.

If a check fails, keep the failing command and complete error output, and note
whether the Mac is Intel or Apple Silicon. Passing checks on Windows does not
replace this macOS smoke test.

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
