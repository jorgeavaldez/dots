# dots

my dotfiles

## Nushell bootstrap (Windows, macOS, Linux and Termux)

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
permissions/shortcuts. Existing config links are covered below. Termux uses
`install.android.sh` to seed native prerequisites and then the same Nu bootstrap;
see the Android limits and explicit exceptions below.

### Automatic secrets

Linux and Termux use a private file-backed age identity, with no keyring or `op` dependency
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
commented `sources.toml` template if missing, with a `source-age` provider using
the same device identity for encrypted local inputs. Repeating setup preserves
existing entries, providers, identity, and cache; it adds `source-age` if missing.
Both `sources.toml` and the encrypted `config.toml` stay in `~/.config/fnox/` (or `$env.FNOX_CONFIG_DIR`),
**outside dots and not symlinked**. An unrelated existing fnox config stops
enrollment rather than being overwritten.

To create only the reference template, without enrolling a device or fetching
anything, run:

```nu
secrets init
```

The command prints its path and preserves existing entries and comments. On an
enrolled device it also adds `source-age` if missing. `sources.toml` is the source
of truth; `config.toml` is the derived shell cache.

For local API keys, no 1Password CLI or server is required:

```nu
secrets local OPENAI_API_KEY
secrets refresh
```

`secrets local KEY` encrypts a pasted value from fnox's hidden prompt into the
private source file. It also accepts a string piped from a trusted process:

```nu
$env.OPENAI_API_KEY | secrets local OPENAI_API_KEY
```

There is no value argument, so secrets need not appear in shell history or argv.
To copy from the 1Password phone app, start the hidden prompt, copy the key,
return and paste, then clear the clipboard and any keyboard clipboard history.
No supported Android-app-to-Termux CLI integration is required. Run refresh after
adding or rotating keys. Delete their `[secrets]` entries and refresh to remove
them from the cache. Avoid `fnox set --global` for managed keys: refresh removes
cached keys absent from sources.

For remote provider references or non-sensitive defaults, edit `[secrets]` in
that **private** `sources.toml`:

```toml
[providers.onepassword]
type = "1password"

[secrets]
OPENAI_API_KEY = { provider = "onepassword", value = "op://Vault/Item/credential" }
HOMELAB_URL = { default = "https://example.invalid" }
```

`default` stores a non-sensitive, device-specific value in plaintext in the
private source file; never put credentials there. Provider-backed entries can
use any fnox source provider configured in this file, not just 1Password.
For 1Password, enter `op://` references, not credential values. Authenticate with
your source provider when using remote references, then rebuild the local cache:

```nu
secrets refresh
```

Refresh resolves encrypted local inputs, remote-provider references, and
plaintext defaults into the local age cache and removes entries whose mappings
were deleted. The native hook reads only the cache, not `sources.toml`.
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
vault, item, and field references and plaintext defaults are not stored in this
repository; only the empty template is shared. If moving from the old repository-local
`fnox/sources.toml`, move it to the private fnox directory before starting a new
shell; that old repository path is now ignored. Do not share device identities
or encrypted caches. For each project on the new device, check out its references
and run the project sync command to build that device's local cache. The old Zsh
setup is unchanged; Termux now uses the shared Nu integration.

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

The ARM64 Android entrypoint seeds native **mise, Nushell and Node.js/npm**
plus the existing Termux essentials in `termux/packages.txt`. Optional native
packages follow the Android selection, not an unconditional pkg list.
It retains Pi's supported native npm distribution and Herdr setup, and downloads
the musl jj binary needed by the shared-storage wrapper. It then hands off to
`bootstrap.nu`. It no longer installs fnox separately or owns shared config
links. Existing Zsh files and the login shell are unchanged; start `nu` explicitly.
`./install.android.sh --dry-run` requires the native seed to be present and
previews shared bootstrap without package/network changes. There is no destructive
`--force`: files are backed up and directory conflicts stop setup.

`mise/config.toml` remains the unchanged canonical tool/version catalog. The
`termux/config.android.toml` overlay is installed as
`$MISE_CONFIG_DIR/config.android.toml` (default `~/.config/mise`). Its native
`settings.enable_tools` allowlist defaults to **nu, node, fnox, age, zoxide,
carapace, go and zig**. Mise filters unselected global and project declarations
before version/metadata resolution, including GitHub Pi and Cargo nufmt. Native
Pi and the compiled `~/.local/bin/nufmt` remain independent exceptions.

Opt in or out by creating the **device-local**, untracked
`~/.config/mise/config.android.local.toml` (or under your `MISE_CONFIG_DIR`):

```toml
[settings]
enable_tools = ["nu", "node", "fnox", "age", "zoxide", "carapace", "go", "zig", "java"]
```

This replaces the selection, not versions. Keep the six core integration names;
setup rejects removing them or selecting shared Pi/nufmt. The local file may
only contain `settings.enable_tools`. Rerun the installer after changing native
tool opt-ins. The overlay lives under `termux/` so mise does not rediscover
it as a project default in this checkout and override device-local settings.
Bootstrap checks native effective selection before installation; it neither
creates a second catalog nor looks up selection/tool paths during startup.
Android uses native `less -FRX` rather than an unselected ov. Starship quietly
omits its optional jj-starship module when that executable is absent.

The overlay selects verified GitHub backends for Nu,
fnox, age (including age-keygen), zoxide and carapace. **Nu is a native pkg runtime
exception**, not just a seed: normal HTTPS `http get` fails DNS resolution in the
tested musl Nu 0.116.0 on Termux, while native Nu 0.116.0 succeeds. Mise registers
native Nu through `$XDG_DATA_HOME/dots/pkg/nu/bin/nu` and Node/npm/npx through
three symlinks in `$XDG_DATA_HOME/dots/pkg/node/bin`, never the whole `$PREFIX`
(which would shadow managed tools). Musl Nu can report `linux`, so bootstrap
also recognizes Termux's environment markers. npm tools remain mise-managed,
except the existing native Pi distribution.

**ShellCheck is an optional native pkg exception.** Aqua requests an
Android-named archive that upstream does not publish; upstream v0.11.0's static
Linux ARM64 binary is killed by Android seccomp at `set_robust_list` (`SIGSYS`)
on the audited device. Add `shellcheck` to the device-local `enable_tools` list
and rerun the installer. It installs the native `shellcheck` package, and
bootstrap registers only `$PREFIX/bin/shellcheck` through
`$XDG_DATA_HOME/dots/pkg/shellcheck/bin/shellcheck`. Mise selects this dedicated
root; Termux package upgrades own its version. The compatibility mapping lives
in the shared Android overlay, so no generic `config.local.toml` override is
needed.

**Go retains the native golang package through mise's path registration** at
`$XDG_DATA_HOME/dots/pkg/go -> $PREFIX/lib/go`. Upstream mise Go 1.27.1 reports
Linux host/target defaults: a compiled pure-Go networking program fails Android
DNS, and default cgo linking fails on `__android_log_vprint`. Explicit
`GOOS=android GOARCH=arm64 CGO_ENABLED=1 CC=$PREFIX/bin/clang` succeeds for both
cgo and DNS/verified HTTPS, but silently changing those defaults is not native
host parity. Native Go has Android host/target defaults and passes the same
networking and cgo proofs without overrides. Keep its full compiler/runtime
root; do not register just the go executable.

**Zig uses mise's upstream 0.16.0 binary**, not a redundant pkg copy. Compiled
Zig executables run both with the default musl target and explicit
`-target aarch64-linux-android`. A C allocation/stdio program also compiles and
runs against Bionic with explicit Termux headers, CRTs and system libraries:

```sh
zig cc -target aarch64-linux-android \
  -isystem "$PREFIX/include" -isystem "$PREFIX/include/aarch64-linux-android" \
  main.c "$PREFIX/lib/crtbegin_dynamic.o" \
  /system/lib64/libc.so /system/lib64/libm.so /system/lib64/libdl.so \
  "$PREFIX/lib/crtend_android.o" -nostdlib \
  -Wl,--dynamic-linker=/system/bin/linker64 -o main
```

Neither the audited native nor upstream Zig automatically discovers Android
libc for plain `zig cc`. This is an explicit target/linking requirement, not a
claim of automatic Android libc or full desktop toolchain parity.

Java, Erlang and Elixir are **optional**, narrow native exceptions: Java's Android
metadata URL returns 404 and the default Erlang backend selects Ubuntu artifacts.
Only when selected, bootstrap links the dedicated package trees `lib/jvm/java-25-openjdk`,
`lib/erlang` and `opt/elixir` under `$XDG_DATA_HOME/dots/pkg/{java,erlang,elixir}`.
These retain JDK libraries and companion commands (`javac`, `jar`, `keytool`,
`erlc`, `escript`, `epmd`, `elixirc`, `iex`, `mix`); mise exports `JAVA_HOME`
from the JDK root. The audited native versions are **OpenJDK 25.0.4,
Erlang/OTP 29.1.1 and Elixir 1.20.4 (compiled with OTP 29)**, not an assertion
that native packages equal desktop `latest`. Termux package updates own native
patch versions; no Java 26 language requirement has been established.
Java HTTPS uses the JDK's bundled trust store. Mix compilation locking requires
hard links denied by native Termux; the Android overlay uses Mix's supported
`MIX_OS_CONCURRENCY_LOCK=0` opt-out. **Serialize Mix builds sharing a build
directory**: cross-process compilation locking is unavailable on this device.

Android bootstrap uses ordinary **filtered `mise install`**, not a hardcoded
ten-tool list. Only selected native roots are preflighted/registered. Java/BEAM
backend mappings remain available for future opt-in, as does ShellCheck; none
are defaults.
Other catalog entries remain disabled, not deleted or implicitly installed.
Selecting an additional name is an opt-in, not a promise of Android support.

Android-only `settings.npm.shell_out=true` is an explicitly approved workaround
for mise 2026.9.14's embedded npm TLS verifier requiring a JVM context unavailable
in Termux. **TLS certificate and hostname verification stay enabled**, install
scripts remain disabled by default, and the tested npm install propagated release
age. However, npm shell-out **bypasses aube's extra trust-downgrade check**; it is
not security-equivalent to the embedded backend. No insecure TLS setting is used.
Keep Termux's termux-exec/`LD_PRELOAD` support for npm shebangs.

Android overlay discovery is enabled by `MISE_AUTO_ENV=1` in bootstrap, Nu startup
and explicit `secrets setup-shell` tool resolution. XDG and `MISE_CONFIG_DIR`
overrides are preserved. An explicit `MISE_GLOBAL_CONFIG_FILE` suppresses adjacent
overlays in the tested mise version, and an explicit `MISE_AUTO_ENV=0/false`
disables them: setup/startup fail before using the wrong backends rather than
silently overriding those choices. Explicitly unset those overrides and use
`MISE_CONFIG_DIR` if you want this integration. Custom override-file support
requires separate work. Bootstrap preserves local fnox configs and never enrolls
credentials. `secrets setup`/`--identity` and `secrets refresh` use the same private
age-file path and permissions as Linux; see [Linux secrets setup](docs/linux-secrets.md).
After fnox/zoxide upgrades, regenerate static hooks explicitly via
`secrets setup-shell` and bootstrap respectively, never startup tool lookups.

Nu uses Termux:API's `termux-clipboard-set/get`, preserving UTF-8 and trailing
newlines (the Android API app must be available). Locale defaults to
`en_US.UTF-8` without replacing explicit LANG/LC_CTYPE values; Android's Bionic
recognizes it without locale-gen. Nu preserves inherited SSH agents (including
forwarded Herdr sockets), or reuses the termux-services socket if no agent was
inherited. It never loads keys or enrolls credentials; unlock your keys explicitly
when needed. No Vicinae desktop state or WezTerm terminfo download is created on
Android. PRoot is used for the jj shared-storage and agent-browser DNS wrappers,
not a Linux distro.
Nu's `jj` command and its aliases dispatch through that wrapper even after mise
reorders PATH; `^jj` explicitly bypasses Nu commands and follows external PATH.

### Agent-browser DNS on Android

`bootstrap.nu` links `termux/agent-browser-wrapper.sh` as
`~/.local/bin/agent-browser`. Keep that directory ahead of other agent-browser
installations on PATH; Pi's native tool also resolves this external command.
The launcher uses the unchanged npm-installed Linux-musl ARM64 binary at
`$PREFIX/lib/node_modules/agent-browser/bin/agent-browser-linux-musl-arm64`.
If it is missing, install upstream with `npm install --global --ignore-scripts agent-browser`.
Chromium setup remains upstream/Termux-owned.

URL `read` runs in the upstream daemon, whose musl resolver expects
`/etc/resolv.conf`. PRoot maps `$PREFIX/etc/resolv.conf` there without root,
a Linux distro, or system-file changes. The launcher streams CLI stdin/stdout/stderr
and returns its exit code without waiting for or killing the detached daemon.
The tracer exits when that daemon closes or reaches its normal idle timeout.
After installing this launcher, close any older **affected session** once before
retrying: an already-running daemon cannot acquire the new mapping. Restart Pi
if its inherited PATH does not contain `~/.local/bin` ahead of the old command.
Upstream npm upgrades leave the dotfiles launcher untouched.

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
