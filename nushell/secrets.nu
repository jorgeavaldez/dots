# Device enrollment and global cache refresh; fnox's native hook owns loading.
const dots = path self | path expand | path dirname | path dirname
use platform.nu [termux android-mise]

# Explicit setup/refresh only, never shell startup: mise lookups are expensive.
# Resolve the shared tool versions independently of the current project.
def --env installed-tool [name: string] {
    android-mise
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

# Create the private source map; enrolled devices also get local age storage.
# Never fetch secrets or replace existing entries/providers.
export def init [] {
    let sources = (sources-path)
    if not ($sources | path exists) {
        mkdir ($sources | path dirname)
        if $nu.os-info.name == "linux" or (termux) {
            do --capture-errors { ^chmod 700 ($sources | path dirname) }
        }
        '# Private source of truth. Keep this file outside dots.
# After secrets setup: secrets local KEY (hidden paste), or pipe a value into it.
# Local keys are encrypted with source-age using the enrolled device identity.
# Run secrets refresh after changes to rebuild config.toml for shell loading.
# Delete a [secrets] entry and refresh to remove it from the cache.
# KETCH_HTTP_HEADERS is derived from the CF_ACCESS_* tokens during refresh.
[providers.onepassword]
type = "1password"

[secrets]
# OPENAI_API_KEY = { provider = "onepassword", value = "op://Vault/Item/credential" }
# Non-sensitive, device-specific values can be stored here as plaintext defaults.
# HOMELAB_URL = { default = "https://example.invalid" }
' | save $sources
        if $nu.os-info.name == "linux" or (termux) {
            do --capture-errors { ^chmod 600 $sources }
        }
        print $"Created empty secrets template: ($sources)"
    } else {
        print $"Existing secrets references preserved: ($sources)"
    }
    let config = (config-path)
    if ($config | path exists) {
        let provider = (open $config).providers?.dots-age?
        if $provider != null and (open $sources).providers?.source-age? == null {
            # Append instead of rewriting the user's references and comments.
            if $nu.os-info.name == "linux" or (termux) {
                do --capture-errors { ^chmod 600 $sources }
            }
            "\n# Encrypted local source; shares the enrolled device identity.\n" + ({
                providers: {source-age: $provider}
            } | to toml)
            | save --append $sources
        }
    }
}

# Store in the authoritative source map, never directly in the derived cache.
# No value argument: stdin or fnox's hidden prompt keeps keys out of argv/history.
export def local [name: string]: nothing -> nothing, string -> nothing {
    let value = $in
    if $name == "DOTS_AGE_IDENTITY" {
        error make {msg: "DOTS_AGE_IDENTITY is reserved for the device key."}
    }
    if $name == "KETCH_HTTP_HEADERS" {
        error make {msg: "KETCH_HTTP_HEADERS is derived during refresh. Store CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET instead."}
    }
    let config = (config-path)
    if not ($config | path exists) { error make {msg: "Run secrets setup first."} }
    if (open $config).providers?.dots-age? == null { error make {msg: "Run secrets setup first."} }
    init
    let sources = (sources-path)
    let fnox = (installed-tool fnox)
    if $value == null {
        ^$fnox --config $sources --profile default --no-daemon set $name --provider source-age
    } else {
        $value | ^$fnox --config $sources --profile default --no-daemon set $name --provider source-age
    }
    print $"Stored ($name) in sources.toml. Run secrets refresh to update the shell cache."
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

# Linux and Termux use a private file, not a desktop keychain or an SSH agent.
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
        init
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
    print "Secrets device configured with a private age file. Use secrets local KEY or add provider references, then secrets refresh."
}

# One-time enrollment; never replace an existing device identity.
export def setup [--identity: path] {
    if $nu.os-info.name == "linux" or (termux) {
        setup-linux $identity
        return
    }
    if $identity != null { error make {msg: "File identity import is Linux/Termux-only; native credential storage is unchanged."} }
    if $nu.os-info.name not-in ["windows" "macos"] {
        error make {msg: "Secrets setup currently supports Windows and macOS only."}
    }
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
        init
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
    init
    print $"Secrets device configured. Use secrets local KEY or add references to (sources-path), then run secrets refresh."
}

# Refresh the global cache; the native hook reloads it at the next prompt.
export def refresh [--if-enrolled] {
    if $nu.os-info.name not-in ["windows" "macos" "linux"] and not (termux) {
        error make {msg: "Secrets refresh supports Windows, macOS, Linux and Termux."}
    }

    let config = (config-path)
    let local = if ($config | path exists) { open $config } else { null }
    if $local.providers?.dots-age? == null {
        if $if_enrolled {
            print "Secrets refresh skipped: device is not enrolled. Run secrets setup to enroll."
            return
        }
        error make {msg: "Run secrets setup first."}
    }

    let sources = (sources-path)
    if not ($sources | path exists) { error make {msg: "Run secrets init to create your private sources.toml."} }

    let entries = open $sources | get secrets
    let source_names = $entries | columns
    if "DOTS_AGE_IDENTITY" in $source_names {
        error make {msg: "DOTS_AGE_IDENTITY is reserved for the device key."}
    }
    if "KETCH_HTTP_HEADERS" in $source_names {
        error make {msg: "KETCH_HTTP_HEADERS is derived during refresh. Remove its entry from sources.toml; keep the CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET sources."}
    }
    let ketch_headers = "CF_ACCESS_CLIENT_ID" in $source_names and "CF_ACCESS_CLIENT_SECRET" in $source_names
    let names = if $ketch_headers {
        $source_names | append "KETCH_HTTP_HEADERS"
    } else { $source_names }

    let plaintext = ($entries | transpose name secret | where {|entry|
        $entry.secret.default? != null and $entry.secret.provider? == null and $entry.secret.value? == null
    } | get name)
    let sourced = $source_names | where {|name| $name not-in $plaintext }
    let fnox = (installed-tool fnox)
    let removed = ($local.secrets | transpose name secret | where {|entry|
        $entry.secret.provider? == "dots-age" and $entry.name not-in $names
    } | get name)

    # Keep the live cache usable while syncing; publish only after success.
    let staging = $config | path dirname | path join $".dots-refresh-(random uuid)"
    let pending = $staging | path join "config.toml"
    mkdir $staging
    try {
        if $nu.os-info.name == "linux" or (termux) {
            do --capture-errors { ^chmod 700 $staging }
        }
        cp $config $pending
        if ($sourced | is-not-empty) {
            let result = (with-env {FNOX_CONFIG_DIR: $staging} {
                ^$fnox --config $sources --profile default --no-daemon --non-interactive --if-missing error sync --global --provider dots-age --force ...$sourced | complete
            })
            if $result.exit_code != 0 {
                error make {msg: $"Secrets refresh failed (fnox exit ($result.exit_code)). Check source-provider access and the references in ($sources). The previous cache and shell environment were preserved."}
            }
        }
        for name in $plaintext {
            let stored = (
                $entries
                | get $name
                | get default
                | ^$fnox --config $pending --profile default --no-daemon --non-interactive set $name --provider dots-age
                | complete
            )
            if $stored.exit_code != 0 {
                error make {msg: $"Could not encrypt ($name) into the staged cache (fnox exit ($stored.exit_code)). The previous cache was preserved."}
            }
        }
        let updated = (open $pending)
        mut cache = $updated.secrets
        for name in $sourced {
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
        if $ketch_headers {
            # Read the newly refreshed cache, never stale inherited shell tokens.
            let client_id = (
                ^$fnox --config $pending --profile default --no-daemon --non-interactive get CF_ACCESS_CLIENT_ID
                | complete
            )
            let client_secret = (
                ^$fnox --config $pending --profile default --no-daemon --non-interactive get CF_ACCESS_CLIENT_SECRET
                | complete
            )
            if $client_id.exit_code != 0 or $client_secret.exit_code != 0 {
                error make {msg: "Could not read refreshed Cloudflare Access tokens. The previous cache was preserved."}
            }
            let headers = {
                "CF-Access-Client-Id": ($client_id.stdout | str trim)
                "CF-Access-Client-Secret": ($client_secret.stdout | str trim)
            }
            let ketch = open ($dots | path join "ketch" "config.json")
            mut origins = {}
            for url in [$ketch.searxng_url $ketch.firecrawl_url] {
                let origin = $url | url parse | select scheme host port | url join
                $origins = $origins | upsert $origin $headers
            }
            let stored = (
                $origins
                | to json --raw
                | ^$fnox --config $pending --profile default --no-daemon --non-interactive set KETCH_HTTP_HEADERS --provider dots-age
                | complete
            )
            if $stored.exit_code != 0 {
                error make {msg: "Could not encrypt KETCH_HTTP_HEADERS into the staged cache. The previous cache was preserved."}
            }
        }
        if $nu.os-info.name == "linux" or (termux) {
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
