# dots

my dotfiles

## Nushell bootstrap (Windows, macOS, and Linux)

Start with a copy of this repository and:

- **Windows:** Nushell installed through WinGet, with WinGet on PATH. File
  symlinks require Developer Mode or an elevated Nu terminal. The installer
  checks that permission before changing configs or installing packages; it
  does not change Windows security settings. Package installers may show UAC.
- **macOS:** Nushell and Homebrew installed. If Apple's Command Line Tools are
  missing, finish the prompted installation and rerun the bootstrap.
- **Linux (Arch or Debian):** mise, Nushell, Git, and system/build prerequisites
  are already installed and on PATH. Bootstrap does not detect or invoke apt,
  pacman, Homebrew, or a prerequisite installer on Linux.

Run from the checkout (it does not have to be `~/dots`):

```nu
nu --no-config-file bootstrap.nu --dry-run
nu --no-config-file bootstrap.nu
```

On Windows/macOS, the Nu installer installs mise if missing, connects the shared mise config,
uses its `[bootstrap.packages]` to install missing WinGet/Homebrew packages,
ensures compiler prerequisites, then installs missing `[tools]` with mise.
`mise/config.toml` is the only package/tool list. WinGet is preferred for Windows
system packages; no Scoop fallback is currently needed. Ripgrep and Carapace
are mise-managed. The Windows C++ check verifies both the compiler and Windows
SDK, and adds the Visual C++ workload when either is missing. A required reboot
stops setup with instructions to rerun afterward. On Intel Macs, bootstrap applies
those same package declarations through the installed Homebrew CLI because mise's
native Homebrew manager supports only Apple Silicon on macOS.

On Linux, it connects that same mise config and runs `mise install --yes`
without a system-package step. Nu itself is now mise-managed too.
The 1Password CLI remains optional on Linux; fnox and age are installed by mise.
On desktops that use 1Password, keep the existing CLI/SSH-agent installation.
No SSH configuration, identity, agent socket, or login shell is changed.

Use **this Nu entrypoint** for the Nu migration. `mise install` alone does not
install system packages or configure compiler workloads. Bootstrap doesn't
force upgrades of already-installed system applications.

### Connected configs

| Shared source | Destination |
| --- | --- |
| `mise/config.toml` | `~/.config/mise/config.toml` by default |
| `nushell/env.nu`, `nushell/config.nu` | Nu's own startup paths |
| `wezterm/` | `~/.config/wezterm` (respects XDG on macOS/Linux) |
| `jj/config.toml` | jj's user config path; `%APPDATA%/jj/config.toml` on fresh Windows |
| `herdr/config.toml` | `%APPDATA%/herdr/config.toml` on Windows; `~/.config/herdr/config.toml` on macOS/Linux |
| `git/config`, `git/ignore` | `~/.gitconfig`, `~/.gitignore` |
| `.tmux.conf`, `.vimrc`, `zellij/config.kdl` | Home dotfiles and XDG Zellij config on macOS/Linux |
| `starship.toml` | `$STARSHIP_CONFIG` or `~/.config/starship.toml` (config only, no prompt activation) |
| `yazi/*.toml` | Yazi config directory; existing plugins/flavors stay local, macOS keymap selected on macOS |
| `vicinae/` | `~/.config/vicinae/dots` on macOS/Linux, with local imported settings preserved |

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

The macOS/Linux bootstrap also installs WezTerm terminfo into `~/.terminfo`. WezTerm
starts Nu on all supported platforms; macOS/Linux Nu sets `SHELL` for tmux/Zellij child panes.
The system login shell and all Zsh startup files are unchanged. WezTerm already
bundles the configured JetBrains Mono font.

See [Linux bootstrap details and tests](docs/bootstrap-linux.md) for Arch/Debian.

### Interactive Nu

- Vi editing, mise/zoxide, and Carapace external completions. Completion bridges
  to Bash/Zsh/Fish are disabled; aliases such as `j` and `dco` keep their expansion.
- `pbcopy` / `pbpaste` use the native macOS/Windows clipboard, `wl-copy`/`wl-paste`
  on Wayland, or `xclip` on X11, preserving UTF-8 text and trailing newlines.
  Linux clipboard tools are assumed installed; headless SSH sessions need none.
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
configure SSH authentication, install Yazi plugins/flavors, or configure desktop
permissions/shortcuts. Existing config links are covered below. Termux remains
on `install.android.sh` and `pkg`; its Nu migration is separate. The Nu bootstrap
rejects Termux rather than attempting to run mise there.

### Automatic secrets

Linux uses a private file-backed age identity, with no keyring or `op` dependency
for local encrypted secrets. See [Linux secrets setup](docs/linux-secrets.md)
for enrollment and provisioning devices that do not run 1Password. SSH auth is
independent: Nu preserves the inherited agent, and regular OpenSSH continues to
use device-local keys/config. It does not start keychain or replace your agent.

On Windows/macOS, bootstrap installs fnox, age, and the 1Password CLI. After opening a new Nu session,
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

Refresh updates the global cache and removes entries whose mappings were deleted.
fnox's native shell hook applies the changes at the next prompt. Repeat refresh
after adding references or rotating keys; existing child processes need restarting
to see updates. `DOTS_AGE_IDENTITY` is reserved for the device identity and is
never exported.

Bootstrap runs `secrets setup-shell` to generate `fnox activate nu` into Nu's
device-local `vendor/autoload/fnox.nu`, without enrolling a device or resolving
secrets. Interactive Nu sessions only load that file: no startup tool-path lookup
or regeneration. fnox owns environment loading and follows project configs as you
change directories. Its pre-prompt hook skips resolution
when configs and relevant settings are unchanged. Pi and other child processes
inherit the loaded variables. Global keys still resolve from the local encrypted
cache; new mappings in `sources.toml` require `secrets refresh` before they
become available. Locking 1Password does not lock the independent local cache.

For project-specific keys, commit only the 1Password references in `fnox.toml`,
ignore `fnox.local.toml`, and run from the project directory (replace `onepassword`
with the project's source-provider name):

```nu
fnox sync --provider dots-age --local-file --source onepassword
```

The next prompt loads the encrypted project cache; commands no longer need a
`fnox exec` prefix in that interactive shell. Re-run sync after rotating project
keys. Unlike the former global-only startup loader, native integration can contact
1Password for uncached project references. Sync before relying on offline use.
`secrets refresh` refreshes global keys, not project caches.

Non-interactive Nu no longer loads secrets itself; it can inherit them from an
interactive parent, or scripts can explicitly use `fnox exec -- <command>`.
Existing shells keep their old setup until restarted. After upgrading fnox, or
if its generated integration is missing, run this explicit setup command and
open a new shell:

```nu
secrets setup-shell
```

If an old shell has not loaded that command yet, run it without startup files:

```nu
nu --no-config-file -c 'use ~/dots/nushell/secrets.nu; secrets setup-shell'
```

Adjust `~/dots` if your checkout lives elsewhere. This changes only the generated
integration, not secret caches or device keys. The old `dots-fnox-path` cache is
no longer used. Never add `mise which`/`mise where` lookups to shell startup to
refresh this file; keep that work in bootstrap or explicit setup.

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
or encrypted caches. For each project on the new device, check out its references
and run the project sync command to build that device's local cache. The old Zsh
setup and Termux integration are unchanged.

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

### macOS: Cargo fails with `unknown architecture arm64e.x1-macos`

A Cargo failure such as `could not compile libc (build script)` can hide an
Apple SDK/linker mismatch. Inspect the preceding linker error. In the observed
case, `cc` selected `MacOSX27.0.sdk`, but its linker could not parse that SDK's
`arm64e.x1-macos` entries. Rust and Nu correctly detected Apple Silicon.

Check the selected tools and available SDKs from Nu:

```nu
rustc -vV
xcrun clang --version
xcrun --show-sdk-path
ls /Library/Developer/CommandLineTools/SDKs
```

On the affected Mac, the installed `MacOSX26.5.sdk` worked. If that SDK exists
on your machine, temporarily select it for the failing install:

```nu
with-env {SDKROOT: "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"} {
    mise install "cargo:https://github.com/nushell/nufmt"
}
```

For the full bootstrap, use the same scoped override:

```nu
with-env {SDKROOT: "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"} {
    nu --no-config-file bootstrap.nu
}
```

The nufmt install was verified with this override; the full bootstrap was not
rerun as part of that investigation. This is a temporary machine-local workaround.
Do not add the SDK pin to shared shell or mise configuration, or edit SDK files.
The underlying Command Line Tools/SDK mismatch still needs repair; afterward,
verify builds without the override.

## Legacy Zsh installer

For Linux/macOS Nu setup, use `bootstrap.nu` above, not this legacy entrypoint.


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

Shell files use `shfmt`; Nushell files use `nufmt` (both declared in mise).
`make lint` also runs Nu's native `nu-check --debug` parser check. This checks
syntax and parse-time imports, not a separate semantic/style linter.

```bash
make format
```

Check formatting and Nu syntax without modifying tracked files:

```bash
make lint
# or
make check
```

See which files are included:

```bash
make shell-files
```

`scripts/nu-lint.nu` discovers Nu files automatically through Git, including new
non-ignored `*.nu` files. To select specific paths, quote names with spaces:

```nu
nu --no-config-file scripts/nu-lint.nu check 'path with spaces.nu'
nu --no-config-file scripts/nu-lint.nu format 'path with spaces.nu'
```

Checks run with a disposable HOME/XDG and generated mise/zoxide
imports; they do not execute bootstrap, startup configs, or secrets hooks.
This isolates the environment, not filesystem access: only check trusted code.
The lint targets expect `nu`, `mise`, `zoxide`, `shfmt`, and `nufmt` on PATH.
CI pins the nufmt source revision because upstream has no published release.
