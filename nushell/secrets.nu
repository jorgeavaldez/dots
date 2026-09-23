# Device enrollment and global cache refresh; fnox's native hook owns loading.
const dots = path self | path expand | path dirname | path dirname

# Explicit setup/refresh only, never shell startup: mise lookups are expensive.
# Resolve the shared tool versions independently of the current project.
def installed-tool [name: string] {
    let result = (^mise --cd $dots which $name | complete)
    if $result.exit_code != 0 {
        error make {msg: $"Install ($name) with bootstrap.nu before using secrets."}
    }
    $result.stdout | str trim
}

def config-path [] {
    $env.FNOX_CONFIG_DIR? | default ($nu.home-dir | path join ".config" "fnox") | path join "config.toml" | path expand
}

def sources-path [] {
    config-path | path dirname | path join "sources.toml"
}

# Create a private, empty reference map without enrolling a device or fetching keys.
export def init [] {
    let sources = (sources-path)
    if not ($sources | path exists) {
        mkdir ($sources | path dirname)
        if $nu.os-info.name == "linux" {
            do --capture-errors { ^chmod 700 ($sources | path dirname) }
        }
        '# Private 1Password references. Keep this file outside dots.
[providers.onepassword]
type = "1password"

[secrets]
# OPENAI_API_KEY = { provider = "onepassword", value = "op://Vault/Item/credential" }
' | save $sources
        if $nu.os-info.name == "linux" {
            do --capture-errors { ^chmod 600 $sources }
        }
        print $"Created empty secrets template: ($sources)"
    } else {
        print $"Existing secrets references preserved: ($sources)"
    }
}

# Bootstrap and post-upgrade setup share this owner; no secrets are resolved.
export def setup-shell [] {
    let fnox = (installed-tool fnox)
    let script = (do --capture-errors { ^$fnox activate nu })
    let target = $nu.data-dir | path join "vendor" "autoload" "fnox.nu"
    mkdir ($target | path dirname)
    $script | save --force $target
    print $"Installed native fnox integration: ($target). Open a new Nu shell to use it."
}

# Linux uses a private file, not a desktop keychain or an SSH agent.
def setup-linux [identity_file] {
    let directory = config-path | path dirname
    mkdir $directory
    do --capture-errors { ^chmod 700 $directory }
    let lock = $directory | path join ".dots-setup.lock"
    # External mkdir (no -p) is atomic; a contender must never remove this lock.
    let acquired = (^mkdir --mode=700 -- $lock | complete)
    if $acquired.exit_code != 0 {
        error make {msg: $"Could not acquire enrollment lock ($lock). Another setup may be running; retry after it finishes."}
    }
    try {
        setup-linux-locked $identity_file
    } catch {|err|
        do --capture-errors { ^rmdir -- $lock }
        error make {msg: $err.msg}
    }
    do --capture-errors { ^rmdir -- $lock }
}

# All existing-config and orphan-identity checks run while holding the lock.
def setup-linux-locked [identity_file] {
    let config = (config-path)
    let key = $config | path dirname | path join "age.txt"
    let age_keygen = (installed-tool age-keygen)
    if ($config | path exists) {
        if $identity_file != null { error make {msg: "Device already enrolled; importing would replace its identity."} }
        let local = open $config
        let existing = $local.providers.dots-age.key_file?
        if $existing == null {
            error make {msg: "Existing fnox config is not a dots file-identity config. It was not replaced."}
        }
        let checked = (^$age_keygen -y ($existing | path expand) | complete)
        if $checked.exit_code != 0 {
            error make {msg: "Existing device identity is unreadable. Identity and cache were not replaced."}
        }
        if ($checked.stdout | str trim) not-in $local.providers.dots-age.recipients {
            error make {msg: "Existing identity does not match the configured recipient. Nothing was replaced."}
        }
        print "Secrets device already configured; identity and cache preserved."
        return
    }
    if ($key | path exists) and ($identity_file == null or ($identity_file | path expand) != $key) {
        error make {msg: "An age identity already exists without a config. Import it explicitly; it was not replaced."}
    }
    mkdir ($config | path dirname)
    do --capture-errors { ^chmod 700 ($config | path dirname) }
    let pending = $config | path dirname | path join $".dots-enroll-(random uuid)"
    mkdir $pending
    try {
        do --capture-errors { ^chmod 700 $pending }
        let pending_key = $pending | path join "age.txt"
        if $identity_file == null {
            let generated = (^$age_keygen -o $pending_key | complete)
            if $generated.exit_code != 0 { error make {msg: "Could not generate the device age identity."} }
        } else {
            cp ($identity_file | path expand) $pending_key
        }
        do --capture-errors { ^chmod 600 $pending_key }
        let recipient = (^$age_keygen -y $pending_key | complete)
        if $recipient.exit_code != 0 { error make {msg: "Could not derive the device age recipient."} }
        let settings = {
            providers: {
                dots-age: {
                    type: "age"
                    recipients: [
                        ($recipient.stdout | str trim)
                    ]
                    key_file: $key
                }
            }
            secrets: {}
        }
        let pending_config = $pending | path join "config.toml"
        $settings | to toml | save $pending_config
        do --capture-errors { ^chmod 600 $pending_config }
        if not ($key | path exists) { mv $pending_key $key } else {
            do --capture-errors { ^chmod 600 $key }
        }
        mv $pending_config $config
    } catch {|err|
        rm --recursive --force $pending
        error make {msg: $err.msg}
    }
    rm --recursive --force $pending
    init
    print "Secrets device configured with a private age file. Use fnox set --global --provider dots-age, or configure sources and refresh."
}

# One-time enrollment; never replace an existing device identity.
export def setup [--identity: path] {
    if $nu.os-info.name == "linux" {
        setup-linux $identity
        return
    }
    if $identity != null { error make {msg: "File identity import is Linux-only; native credential storage is unchanged."} }
    if $nu.os-info.name not-in ["windows" "macos"] {
        error make {msg: "Secrets setup currently supports Windows and macOS only."}
    }
    init
    let config = (config-path)
    let fnox = (installed-tool fnox)
    if ($config | path exists) {
        let local = (open $config)
        if $local.providers.dots-age? == null {
            error make {msg: $"Existing fnox config at ($config). Preserve or integrate it before running secrets setup."}
        }
        let identity = (
            ^$fnox --config $config --profile default --no-daemon --non-interactive get DOTS_AGE_IDENTITY
            | complete
        )
        if $identity.exit_code != 0 {
            error make {msg: "The existing device identity could not be read from the OS credential store. It was not replaced."}
        }
        print "Secrets device already configured; identity and cache preserved. Run secrets refresh to sync."
        return
    }

    let age_keygen = (installed-tool age-keygen)
    let identity = (^$age_keygen | complete)
    if $identity.exit_code != 0 { error make {msg: "Could not generate the device age identity."} }
    let recipient = $identity.stdout | ^$age_keygen -y | complete
    if $recipient.exit_code != 0 { error make {msg: "Could not derive the device age recipient."} }
    let key_name = $"age-(random uuid)"
    let settings = {
        providers: {
            dots-keychain: {type: "keychain", service: "dots"}
            dots-age: {
                type: "age"
                recipients: [
                    ($recipient.stdout | str trim)
                ]
                identity: {provider: "dots-keychain", value: $key_name}
            }
        }
        secrets: {
            DOTS_AGE_IDENTITY: {provider: "dots-keychain", value: $key_name, env: false}
        }
    }
    mkdir ($config | path dirname)
    let pending = $"($config).setup-(random uuid).toml"
    $settings | to toml | save $pending
    try {
        # Stdin keeps the identity out of argv/history; capture all output.
        let stored = (
            $identity.stdout
            | ^$fnox --config $pending --profile default --no-daemon --non-interactive set DOTS_AGE_IDENTITY --provider dots-keychain --key-name $key_name
            | complete
        )
        if $stored.exit_code != 0 {
            error make {msg: $"Could not store the device identity in the OS credential store (fnox exit ($stored.exit_code))."}
        }
        # Keep only our intended config, including env=false, after fnox set.
        $settings | to toml | save --force $pending
        mv $pending $config
    } catch {|err|
        rm --force $pending
        error make {msg: $err.msg}
    }
    print $"Secrets device configured. Add references to (sources-path), then run secrets refresh."
}

# Refresh the global cache; the native hook reloads it at the next prompt.
export def refresh [] {
    if $nu.os-info.name not-in ["windows" "macos" "linux"] {
        error make {msg: "Secrets refresh supports Windows, macOS, and Linux."}
    }

    let config = (config-path)
    if not ($config | path exists) { error make {msg: "Run secrets setup first."} }

    let local = (open $config)
    if $local.providers.dots-age? == null { error make {msg: "Run secrets setup first."} }

    let sources = (sources-path)
    if not ($sources | path exists) { error make {msg: "Run secrets init to create your private sources.toml."} }

    let names = open $sources | get secrets | columns
    if "DOTS_AGE_IDENTITY" in $names {
        error make {msg: "DOTS_AGE_IDENTITY is reserved for the device key."}
    }

    let fnox = (installed-tool fnox)
    let removed = ($local.secrets | transpose name secret | where {|entry|
        $entry.secret.provider? == "dots-age" and $entry.name not-in $names
    } | get name)

    # Keep the live cache usable while syncing; publish only after success.
    let staging = $config | path dirname | path join $".dots-refresh-(random uuid)"
    let pending = $staging | path join "config.toml"
    mkdir $staging
    try {
        if $nu.os-info.name == "linux" {
            do --capture-errors { ^chmod 700 $staging }
        }
        cp $config $pending
        if ($names | is-not-empty) {
            let result = (with-env {FNOX_CONFIG_DIR: $staging} {
                ^$fnox --config $sources --profile default --no-daemon --if-missing error sync --global --provider dots-age --force ...$names | complete
            })
            if $result.exit_code != 0 {
                error make {msg: $"Secrets refresh failed (fnox exit ($result.exit_code)). Check source-provider access and the references in ($sources). 1Password references require an installed, authenticated op CLI. The previous cache and shell environment were preserved."}
            }
        }
        let updated = (open $pending)
        mut cache = $updated.secrets
        for name in $names {
            let secret = $cache | get $name
            # fnox keeps the remote reference plus an encrypted sync stanza.
            # Keep global shell keys local-only; remote references stay in sources.toml.
            if $secret.sync.provider? != "dots-age" {
                error make {msg: $"fnox did not produce the local encrypted cache for ($name)."}
            }
            $cache = (
                $cache
                | upsert $name (
                    $secret
                    | reject sync
                    | upsert provider "dots-age"
                    | upsert value $secret.sync.value
                )
            )
        }
        $updated | update secrets ($cache | reject ...$removed) | to toml | save --force $pending
        if $nu.os-info.name == "linux" {
            do --capture-errors { ^chmod 600 $pending }
        }
        mv --force $pending $config
    } catch {|err|
        rm --recursive --force $staging
        error make {msg: $err.msg}
    }
    rm --recursive $staging
    print $"Refreshed ($names | length) cached secrets. fnox reloads at the next prompt; restart existing child processes to pick up changes."
}
