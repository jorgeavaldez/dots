# Run with: nu --no-config-file bootstrap.nu
# Connect configs only. Requires existing Nushell, mise, and zoxide installations.
const dots = path self | path dirname
use nushell/links.nu symlink

def main [
    --dry-run # Show planned config changes without writing anything.
] {
    # Platform-specific directories stay here. Nu supplies its own startup paths
    # (%APPDATA%/nushell on Windows, ~/Library/Application Support/nushell on macOS).
    let home = $nu.home-dir
    let config_home = ($env.XDG_CONFIG_HOME? | default ($home | path join ".config"))
    let platform = match $nu.os-info.name {
        "windows" => {
            wezterm: ($home | path join ".config" "wezterm")
            nvim: ($env.LOCALAPPDATA | path join "nvim")
        }
        "macos" => {
            wezterm: ($config_home | path join "wezterm")
            nvim: ($config_home | path join "nvim")
        }
        _ => { error make {msg: "This bootstrap supports Windows and macOS. Use install.sh or install.android.sh elsewhere."} }
    }
    let mise_dir = ($env.MISE_CONFIG_DIR? | default ($config_home | path join "mise"))
    let mise_config = ($env.MISE_GLOBAL_CONFIG_FILE? | default ($mise_dir | path join "config.toml"))
    let nvim_source = ($home | path join ".config" "nvim")
    let zoxide_init = ($nu.data-dir | path join "zoxide.nu")

    mut links = [
        {source: ($dots | path join "mise" "config.toml"), destination: $mise_config}
        {source: ($dots | path join "nushell" "env.nu"), destination: $nu.env-path}
        {source: ($dots | path join "nushell" "config.nu"), destination: $nu.config-path}
        {source: ($dots | path join "wezterm"), destination: $platform.wezterm}
    ]
    # Neovim is maintained separately; only Windows needs a second config path.
    if $nu.os-info.name == "windows" and ($nvim_source | path join "init.lua" | path exists) {
        $links = ($links | append {source: $nvim_source, destination: $platform.nvim})
    }

    # Check every destination before changing any files.
    for link in $links {
        if not ($link.source | path exists) {
            error make {msg: $"Missing config source: ($link.source)"}
        }
        if ($link.destination | path expand) == ($link.source | path expand) {
            print $"Already connected: ($link.destination)"
            continue
        }
        if ($link.destination | path type) != null {
            if ($link.source | path type) == "dir" or (($link.destination | path expand | path type) == "dir") {
                error make {msg: $"Config conflict: ($link.destination) already exists. Preserve or move it before rerunning."}
            }
            print $"Will back up: ($link.destination)"
        }
        print $"Will link: ($link.destination) -> ($link.source)"
    }

    print $"Will generate zoxide integration: ($zoxide_init)"
    if $dry_run { return }
    if (which mise | is-empty) {
        error make {msg: "mise must be on PATH before connecting Nu's startup files. Use your existing mise installation, then rerun."}
    }
    # Resolve the installed binary once during setup, not before every prompt.
    let zoxide = if (which zoxide | is-empty) {
        let result = (^mise --cd ($dots | path join "mise") which zoxide | complete)
        if $result.exit_code != 0 {
            error make {msg: "zoxide must be installed before connecting Nu's startup files. Install it through your existing package setup, then rerun."}
        }
        $result.stdout | str trim
    } else {
        "zoxide"
    }
    let zoxide_script = (^$zoxide init nushell)
    mkdir ($zoxide_init | path dirname)
    $zoxide_script | save --force $zoxide_init

    for link in $links {
        if ($link.destination | path expand) == ($link.source | path expand) { continue }
        mkdir ($link.destination | path dirname)
        # Create the link first so a Windows privilege error leaves the original
        # config untouched. Only file links need Developer Mode or elevation.
        let pending = $"($link.destination).dots-link-(random uuid)"
        symlink $link.source $pending
        if ($link.destination | path type) != null {
            let backup = $"($link.destination).before-dots-(random uuid)"
            mv $link.destination $backup
            print $"Saved backup: ($backup)"
        }
        mv $pending $link.destination
        print $"Linked: ($link.destination) -> ($link.source)"
    }
    print "Done. Configs are connected; no shell was reloaded or made the default. Open Nu whenever you're ready."
}
