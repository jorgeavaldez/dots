# Automatic shell-wide secrets; only refresh contacts 1Password.
const dots = path self | path expand | path dirname | path dirname

# Resolve installed tools before mise's first interactive pre-prompt hook.
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
        '# Private 1Password references. Keep this file outside dots.
[providers.onepassword]
type = "1password"

[secrets]
# OPENAI_API_KEY = { provider = "onepassword", value = "op://Vault/Item/credential" }
' | save $sources
        print $"Created empty secrets template: ($sources)"
    } else {
        print $"Existing secrets references preserved: ($sources)"
    }
}

# Cache only the executable path, never decrypted secrets. Mise's lookup can be
# expensive; setup/refresh update the path after tool upgrades.
def fnox-binary [--refresh] {
    let cache = (config-path | path dirname | path join "dots-fnox-path")
    if not $refresh and ($cache | path exists) {
        let executable = (open --raw $cache | str trim)
        if ($executable | path expand | path type) == "file" { return $executable }
    }
    let executable = (installed-tool fnox)
    mkdir ($cache | path dirname)
    $executable | save --force $cache
    $executable
}

# Reused by startup and refresh. Never discover configs from the current project.
export def --env load [] {
    if $nu.os-info.name not-in ["windows" "macos"] { return }
    let config = (config-path)
    if not ($config | path exists) { return }
    let local = (open $config)
    if $local.providers.dots-age? == null { return }
    let cached = ($local.secrets? | default {})
    let sources = (sources-path)
    if not ($sources | path exists) { error make {msg: "Run secrets init to create your private sources.toml."} }
    let names = (open $sources | get secrets | columns)
    let missing = ($names | where {|name| $name not-in ($cached | columns)})
    if ($missing | is-not-empty) {
        error make {msg: $"Run secrets refresh to cache: ($missing | str join ', ')."}
    }
    # Only local age ciphertext is eligible for automatic shell loading.
    # The keychain identity is deliberately env=false.
    let remote = ($cached | transpose name secret | where {|entry|
        ($entry.secret.env? | default true) == true and $entry.secret.provider? != "dots-age"
    })
    if ($remote | is-not-empty) {
        error make {msg: $"Automatic secrets loading requires a local age-only cache. Keep remote references in ($sources)."}
    }
    let fnox = (fnox-binary)
    let result = (^$fnox --config $config --profile default --no-daemon --non-interactive --if-missing error export --format json | complete)
    if $result.exit_code != 0 {
        error make {msg: $"Could not decrypt the local secrets cache (fnox exit ($result.exit_code)). Check the OS credential store or run secrets refresh."}
    }
    $result.stdout | from json | get secrets | load-env
}

# One-time enrollment; never replace an existing device identity.
export def setup [] {
    if $nu.os-info.name not-in ["windows" "macos"] {
        error make {msg: "Secrets setup currently supports Windows and macOS only."}
    }
    init
    let config = (config-path)
    let fnox = (fnox-binary --refresh)
    if ($config | path exists) {
        let local = (open $config)
        if $local.providers.dots-age? == null {
            error make {msg: $"Existing fnox config at ($config). Preserve or integrate it before running secrets setup."}
        }
        let identity = (^$fnox --config $config --profile default --no-daemon --non-interactive get DOTS_AGE_IDENTITY | complete)
        if $identity.exit_code != 0 {
            error make {msg: "The existing device identity could not be read from the OS credential store. It was not replaced."}
        }
        print "Secrets device already configured; identity and cache preserved. Run secrets refresh to sync."
        return
    }

    let age_keygen = (installed-tool age-keygen)
    let identity = (^$age_keygen | complete)
    if $identity.exit_code != 0 { error make {msg: "Could not generate the device age identity."} }
    let recipient = ($identity.stdout | ^$age_keygen -y | complete)
    if $recipient.exit_code != 0 { error make {msg: "Could not derive the device age recipient."} }
    let key_name = $"age-(random uuid)"
    let settings = {
        providers: {
            dots-keychain: {type: "keychain", service: "dots"}
            dots-age: {
                type: "age"
                recipients: [($recipient.stdout | str trim)]
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
        let stored = ($identity.stdout | ^$fnox --config $pending --profile default --no-daemon --non-interactive set DOTS_AGE_IDENTITY --provider dots-keychain --key-name $key_name | complete)
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

# Explicit network boundary. On success, update this shell as well as the cache.
export def --env refresh [] {
    if $nu.os-info.name not-in ["windows" "macos"] {
        error make {msg: "Secrets refresh currently supports Windows and macOS only."}
    }
    let config = (config-path)
    if not ($config | path exists) { error make {msg: "Run secrets setup first."} }
    let local = (open $config)
    if $local.providers.dots-age? == null { error make {msg: "Run secrets setup first."} }
    let sources = (sources-path)
    if not ($sources | path exists) { error make {msg: "Run secrets init to create your private sources.toml."} }
    let names = (open $sources | get secrets | columns)
    if "DOTS_AGE_IDENTITY" in $names {
        error make {msg: "DOTS_AGE_IDENTITY is reserved for the device key."}
    }
    let fnox = (fnox-binary --refresh)
    let removed = ($local.secrets | transpose name secret | where {|entry|
        $entry.secret.provider? == "dots-age" and $entry.name not-in $names
    } | get name)
    # Keep the live cache usable while syncing; publish only after success.
    let staging = ($config | path dirname | path join $".dots-refresh-(random uuid)")
    let pending = ($staging | path join "config.toml")
    mkdir $staging
    cp $config $pending
    try {
        if ($names | is-not-empty) {
            let result = (with-env {FNOX_CONFIG_DIR: $staging} {
                ^$fnox --config $sources --profile default --no-daemon --if-missing error sync --global --provider dots-age --force ...$names | complete
            })
            if $result.exit_code != 0 {
                error make {msg: $"Secrets refresh failed (fnox exit ($result.exit_code)). Check 1Password CLI sign-in and the references in ($sources). The previous cache and shell environment were preserved."}
            }
        }
        let updated = (open $pending)
        mut cache = $updated.secrets
        for name in $names {
            let secret = ($cache | get $name)
            # fnox keeps the remote reference plus an encrypted sync stanza.
            # Publish only ciphertext: startup must have no remote fallback.
            if $secret.sync.provider? != "dots-age" {
                error make {msg: $"fnox did not produce the local encrypted cache for ($name)."}
            }
            $cache = ($cache | upsert $name ($secret | reject sync | upsert provider "dots-age" | upsert value $secret.sync.value))
        }
        $updated | update secrets ($cache | reject ...$removed) | to toml | save --force $pending
        mv --force $pending $config
    } catch {|err|
        rm --recursive --force $staging
        error make {msg: $err.msg}
    }
    rm --recursive $staging
    hide-env --ignore-errors ...$removed
    load
    print $"Loaded ($names | length) cached secrets into this Nu session. Restart existing child processes to pick up changes."
}
