# Run with: nu --no-config-file bootstrap.nu [--dry-run]
# Windows seed: Nushell + WinGet. macOS seed: Nushell + Homebrew.
# Linux (Arch/Debian): mise, Nushell and system prerequisites already installed.
const dots = path self | path dirname
use nushell/links.nu symlink
use nushell/secrets.nu

# Installers update the registry, not this process's inherited PATH.
def --env refresh-system-path [] {
    let paths = if $nu.os-info.name == "windows" {
        let result = (^powershell.exe -NoProfile -NonInteractive -Command '
            @(
                [Environment]::GetEnvironmentVariable("Path", "Machine")
                [Environment]::GetEnvironmentVariable("Path", "User")
            ) -join ";"
        ' | complete)
        if $result.exit_code != 0 { error make {msg: "Could not read the installed Windows PATH."} }
        $result.stdout | str trim | split row ";" | where {|entry| $entry != ""}
    } else if $nu.os-info.name == "macos" {
        [
            "/opt/homebrew/bin"
            "/opt/homebrew/sbin"
            "/usr/local/bin"
            "/usr/local/sbin"
        ]
        | where {|entry| $entry | path exists}
    } else {
        []
    }
    $env.PATH = ($env.PATH | append $paths | uniq)
}

# Create the new link before moving the old config. No copy fallback: edits
# through a connected config must continue to update the dots checkout.
def connect-config [source: path, destination: path, backup: path] {
    if ($destination | path expand) == ($source | path expand) { return }
    mkdir ($destination | path dirname)
    let pending = $"($destination).dots-link-(random uuid)"
    symlink $source $pending
    if ($destination | path type) != null {
        mv $destination $backup
        print $"Preserved: ($backup)"
    }
    mv $pending $destination
    print $"Linked: ($destination) -> ($source)"
}

# Query components, not just the existence of Visual Studio's installer.
def windows-cpp-ready [vswhere: path, installation: path] {
    let compiler = (do --capture-errors {
        ^$vswhere -products Microsoft.VisualStudio.Product.BuildTools -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    } | lines)
    let sdk = (do --capture-errors {
        ^$vswhere -products Microsoft.VisualStudio.Product.BuildTools -requiresAny -requires 'Microsoft.VisualStudio.Component.Windows10SDK.*' 'Microsoft.VisualStudio.Component.Windows11SDK.*' -property installationPath
    } | lines)
    ($installation in $compiler) and ($installation in $sdk)
}

# System packages must already be installed; source builds follow this step.
def ensure-compiler-prerequisites [] {
    refresh-system-path
    match $nu.os-info.name {
        "windows" => {
            let installer_dir = (
                $env
                | get "ProgramFiles(x86)"
                | path join "Microsoft Visual Studio" "Installer"
            )
            let vswhere = $installer_dir | path join "vswhere.exe"
            let installation = (do --capture-errors {
                ^$vswhere -latest -products Microsoft.VisualStudio.Product.BuildTools -property installationPath
            } | str trim)
            if $installation == "" { error make {msg: "Visual Studio Build Tools is missing. Run the full bootstrap first."} }
            if (windows-cpp-ready $vswhere $installation) { return }

            print "Installing the Visual C++ workload and recommended Windows SDK. Windows may request elevation."
            let setup = $installer_dir | path join "setup.exe"
            # VS setup must run outside its own directory. --wait belongs to the
            # bootstrapper, not setup.exe; Nu waits for this process itself.
            cd $dots
            let result = (
                ^$setup modify --installPath $installation --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --norestart
                | complete
            )
            let status = $result.exit_code
            if $status == 3010 {
                error make {msg: "Build Tools requires a reboot. Reboot, then rerun bootstrap.nu."}
            }
            if $status != 0 {
                error make {msg: $"Build Tools installation failed with exit code ($status). If elevation was denied, rerun from an elevated Nu terminal. ($result.stdout)($result.stderr)"}
            }
            if not (windows-cpp-ready $vswhere $installation) {
                error make {msg: "Build Tools finished without the required C++ compiler and Windows SDK."}
            }
        }
        "macos" => {
            let compiler = (^xcrun --find clang | complete)
            if $compiler.exit_code != 0 {
                let install = (^xcode-select --install | complete)
                error make {msg: $"Finish Apple's Command Line Tools installation, then rerun bootstrap.nu. ($install.stderr)"}
            }
        }
        _ => { error make {msg: "This bootstrap supports Windows and macOS only."} }
    }
}

def main [
    --dry-run # Show actions without installing packages or changing files.
] {
    if ($env.TERMUX_VERSION? | default "" | is-not-empty) or ($env.PREFIX? | default "" | str contains "com.termux") or $nu.os-info.name == "android" {
        error make {msg: "Termux is not supported by bootstrap.nu; use install.android.sh."}
    }
    let home = $nu.home-dir
    let config_home = $env.XDG_CONFIG_HOME? | default ($home | path join ".config")
    let platform = match $nu.os-info.name {
        windows => {
            wezterm: ($home | path join ".config" "wezterm")
            jj: ($env.APPDATA | path join "jj" "config.toml")
            herdr: ($env.APPDATA | path join "herdr" "config.toml")
            yazi: ($env.APPDATA | path join "yazi" "config")
        }
        macos | linux => {
            wezterm: ($config_home | path join "wezterm")
            jj: ($config_home | path join "jj" "config.toml")
            herdr: ($config_home | path join "herdr" "config.toml")
            yazi: ($config_home | path join "yazi")
        }
        _ => { error make {msg: "This bootstrap supports Windows, macOS and Linux."} }
    }
    refresh-system-path
    let manager = if $nu.os-info.name == "windows" { "winget" } else { "brew" }

    let mise_dir = $env.MISE_CONFIG_DIR? | default ($config_home | path join "mise")
    let mise_config = (
        $env.MISE_GLOBAL_CONFIG_FILE?
        | default ($mise_dir | path join "config.toml")
    )
    let git_config = $home | path join ".gitconfig"
    let git_local = $home | path join ".gitconfig.local"
    let zoxide_init = $nu.data-dir | path join "zoxide.nu"
    # Let an existing jj resolve its own override/legacy config location.
    let jj_config = if (which jj | is-empty) {
        if $env.JJ_CONFIG? != null {
            error make {msg: "Install jj first so it can resolve your JJ_CONFIG override, or unset JJ_CONFIG for the standard location."}
        }
        $platform.jj
    } else {
        let paths = do --capture-errors { ^jj config path --user } | lines
        if ($paths | length) != 1 { error make {msg: "Expected one jj user config destination."} }
        $paths.0
    }

    mut links = [
        {
            source: ($dots | path join "mise" "config.toml")
            destination: $mise_config
        }
        {
            source: ($dots | path join "mise" "tasks")
            destination: ($mise_dir | path join "tasks")
        }
        # Nu resolves env-path/config-path through existing file symlinks.
        # Link in the config directory instead of overwriting another checkout.
        {
            source: ($dots | path join "nushell" "env.nu")
            destination: ($nu.default-config-dir | path join "env.nu")
        }
        {
            source: ($dots | path join "nushell" "config.nu")
            destination: ($nu.default-config-dir | path join "config.nu")
        }
        {
            source: ($dots | path join "wezterm")
            destination: $platform.wezterm
        }
        {
            source: ($dots | path join "jj" "config.toml")
            destination: $jj_config
        }
        {
            source: ($dots | path join "herdr" "config.toml")
            destination: $platform.herdr
        }
        {
            source: ($dots | path join "git" "config")
            destination: $git_config
        }
        {
            source: ($dots | path join "git" "ignore")
            destination: ($home | path join ".gitignore")
        }
    ]
    $links = ($links | append {
        source: ($dots | path join "starship.toml")
        destination: ($env.STARSHIP_CONFIG? | default ($config_home | path join "starship.toml"))
    })
    let yazi_dir = $env.YAZI_CONFIG_HOME? | default $platform.yazi
    for file in ["yazi.toml" "theme.toml" "package.toml" "keymap.toml"] {
        let source = if $file == "keymap.toml" and $nu.os-info.name == "macos" {
            $dots | path join "yazi" "macos" $file
        } else {
            $dots | path join "yazi" $file
        }
        $links = (
            $links
            | append {source: $source, destination: ($yazi_dir | path join $file)}
        )
    }
    let vicinae_dir = $config_home | path join "vicinae"
    let vicinae_settings = $vicinae_dir | path join "settings.json"
    if $nu.os-info.name in ["macos" "linux"] {
        $links = ($links | append [
            {source: ($dots | path join ".vimrc"), destination: ($home | path join ".vimrc")}
            {source: ($dots | path join "vicinae"), destination: ($vicinae_dir | path join "dots")}
            {source: ($dots | path join ".tmux.conf"), destination: ($home | path join ".tmux.conf")}
            {source: ($dots | path join "zellij" "config.kdl"), destination: ($config_home | path join "zellij" "config.kdl")}
        ])
    }
    $links = ($links | each {|link|
        $link | insert backup (if $link.destination == $git_config {
            $git_local
        } else {
            $"($link.destination).before-dots-(random uuid)"
        })
    })

    # Preflight every destination before installing anything. Existing Git
    # options remain machine-local via the shared config's optional include.
    for link in $links {
        if not ($link.source | path exists) { error make {msg: $"Missing source: ($link.source)"} }
        if ($link.destination | path expand) == ($link.source | path expand) {
            print $"Already connected: ($link.destination)"
            continue
        }
        if ($link.destination | path type) != null {
            if ($link.source | path type) == "dir" or (($link.destination | path expand | path type) == "dir") {
                error make {msg: $"Config conflict: ($link.destination) is an existing directory. Preserve or move it before rerunning."}
            }
            if ($link.backup | path type) != null {
                error make {msg: $"Cannot preserve ($link.destination): ($link.backup) already exists. Merge the machine-local settings before rerunning."}
            }
            print $"Will preserve: ($link.destination) -> ($link.backup)"
        }
        print $"Will link: ($link.destination) -> ($link.source)"
    }
    if $nu.os-info.name == "linux" {
        print "Linux prerequisites are assumed installed (including mise, Nu and build tools)."
    } else {
        print $"Will ensure mise is installed through ($manager)."
    }
    let packages = (
        open ($dots | path join "mise" "config.toml")
        | get bootstrap.packages
        | transpose name options
        | where options.os == $nu.os-info.name
        | get name
    )
    if $nu.os-info.name != "linux" {
        print $"Will apply system packages: ($packages | str join ', ')"
        print "Will ensure compiler prerequisites, then install missing mise tools."
    } else {
        print "Will install missing mise tools; no Linux system package installation."
    }
    if $nu.os-info.name in ["macos" "linux"] {
        if ($vicinae_settings | path type) == null {
            print $"Will create local Vicinae settings importing tracked defaults: ($vicinae_settings)"
        } else {
            print $"Vicinae: preserving ($vicinae_settings). Ensure imports includes dots/settings.json; also dots/macos.json on macOS."
        }
    }
    print $"Will generate zoxide integration: ($zoxide_init)"
    print "Will install native fnox integration through secrets setup-shell (no credential enrollment)."
    if $nu.os-info.name in ["macos" "linux"] { print "Will install WezTerm terminfo into ~/.terminfo." }
    if $dry_run { return }

    if $nu.os-info.name == "windows" {

        # Fail early on missing file-link privileges, without touching configs.
        let probe = (mktemp --dry --suffix .dots-link)
        symlink ($dots | path join "git" "ignore") $probe
        rm $probe
    }
    if $nu.os-info.name != "linux" and (which mise | is-empty) {
        if $nu.os-info.name == "windows" {
            do --capture-errors { ^winget install --id jdx.mise --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity }
        } else {
            do --capture-errors { ^brew install mise }
        }
        refresh-system-path
        if (which mise | is-empty) { error make {msg: "mise installed but is not on PATH. Open a new Nu terminal and rerun."} }
    }

    # Connect mise first so one canonical global config owns package/tool setup.
    let first = $links.0
    connect-config $first.source $first.destination $first.backup
    if $nu.os-info.name == "macos" and $nu.os-info.arch == "x86_64" {
        # Mise's native Homebrew manager does not support Intel Macs.
        # Use the same package declarations with the installed Homebrew CLI.
        for kind in ["formula" "cask"] {
            let prefix = if $kind == "formula" { "brew:" } else { "brew-cask:" }
            let requested = (
                $packages
                | where {|package| $package | str starts-with $prefix}
                | each {|package| $package | str replace $prefix ""}
            )
            let installed = (
                do --capture-errors { ^brew list $"--($kind)" --full-name -1 }
                | lines
            )
            let missing = $requested | where {|package| $package not-in $installed}
            if ($missing | is-not-empty) {
                do --capture-errors { ^brew install $"--($kind)" ...$missing }
            }
        }
    } else if $nu.os-info.name != "linux" {
        do --capture-errors { ^mise --cd $dots bootstrap --only packages --yes }
    }
    refresh-system-path
    if $nu.os-info.name != "linux" { ensure-compiler-prerequisites }
    do --capture-errors { ^mise --cd $dots install --yes }

    let zoxide = do --capture-errors { ^mise --cd $dots which zoxide } | str trim
    let zoxide_script = (do --capture-errors { ^$zoxide init nushell })
    mkdir ($zoxide_init | path dirname)
    $zoxide_script | save --force $zoxide_init
    secrets setup-shell
    for link in ($links | skip 1) {
        connect-config $link.source $link.destination $link.backup
    }

    # The GUI writes this file; only the defaults directory is linked to dots.
    if $nu.os-info.name in ["macos" "linux"] and ($vicinae_settings | path type) == null {
        let imports = if $nu.os-info.name == "macos" {
            ["dots/settings.json" "dots/macos.json"]
        } else {
            ["dots/settings.json"]
        }
        {imports: $imports} | to json | save $vicinae_settings
    }

    if $nu.os-info.name in ["macos" "linux"] {
        let terminfo = (mktemp --suffix .terminfo)
        try {
            http get --raw https://raw.githubusercontent.com/wezterm/wezterm/main/termwiz/data/wezterm.terminfo | save --force $terminfo
            do --capture-errors { ^tic -x -o ($home | path join ".terminfo") $terminfo }
        } catch {|err|
            rm --force $terminfo
            error make {msg: $"Could not install WezTerm terminfo: ($err.msg)"}
        }
        rm $terminfo
    }
    print "Done. Open a new Nu terminal. The system login shell and Neovim installation were not changed."
}
