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

# Captured fnox call that fails with the step, the argv and fnox's own diagnostics.
# Values only ever travel on stdin, so argv and stderr hold names and paths.
# Never write "(fnox ...)" inside $"...": Nu runs it as a command.
def fnox-run [
    fnox: string
    step: string
    help: string
    args: list<string>
]: any -> record {
    let result = $in | ^$fnox ...$args | complete
    if $result.exit_code != 0 {
        let stderr = $result.stderr | ansi strip | str trim
        error make --unspanned {
            msg: ([
                $"($step) failed: fnox exited with code ($result.exit_code)."
                $"Command: ($fnox) ($args | str join ' ')"
                (if $stderr == "" { "fnox printed no diagnostics." } else { $stderr })
            ] | str join "\n")
            help: $help
        }
    }
    $result
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
# Signed in to several 1Password accounts? One provider per account, e.g.
# account = "my.1password.com", and point each entry at the matching provider.

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
            error make {msg: $"Could not store the device identity in the OS credential store: fnox exited with code ($stored.exit_code).\n($stored.stderr | ansi strip | str trim)"}
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

# Sign-in address, its shorthand, email or account/user ID, as op accepts.
def find-account [accounts: table, wanted: string] {
    $accounts | where {|account|
        [
            $account.url
            ($account.url | split row "." | first)
            $account.email
            $account.account_uuid
            $account.user_uuid
        ] | any {|candidate|
            # Case-insensitive equality without the renamed case commands.
            ($candidate | str length) == ($wanted | str length) and ($candidate | str contains --ignore-case $wanted)
        }
    }
}

# op resolves through one default account. On a device signed in to several
# (work and personal), define one 1Password provider per account with fnox's
# account field and point each entry at the right one; unpinned providers are
# rejected there instead of silently reading the wrong account.
def check-onepassword-accounts [providers: record, entries: table] {
    let used = $entries | get secret.provider | uniq
    # A service account has exactly one account and no sign-in list to check.
    if $env.OP_SERVICE_ACCOUNT_TOKEN? != null { return [] }
    let listed = (^op account list --format json | complete)
    if $listed.exit_code != 0 {
        return [$"op account list failed: ($listed.stderr | ansi strip | str trim)"]
    }
    let accounts = $listed.stdout | str trim | if ($in | is-empty) { [] } else { $in | from json }
    let known = $accounts | each {|account| $"($account.url) as ($account.email)" } | str join ", " | if ($in | is-empty) { "none" } else { $in }
    mut problems = []
    for name in $used {
        let account = $providers | get $name | get --optional account
        let users = $entries | where secret.provider == $name | get name | str join ", "
        if $account == null {
            if $env.OP_ACCOUNT? == null and ($accounts | length) > 1 {
                $problems = $problems | append $"1Password provider ($name), used by ($users), has no account while op is signed in to several: ($known). Set account on it, or define one provider per account."
            }
            continue
        }
        let matches = find-account $accounts $account
        if ($matches | length) != 1 {
            let issue = if ($matches | is-empty) { "is not a signed-in 1Password account" } else { "matches several accounts; use the account ID" }
            $problems = $problems | append $"1Password provider ($name) account ($account) ($issue). Signed in: ($known)."
        }
    }
    $problems
}

# Unmet setup conditions, reported together before anything is staged.
def refresh-preflight [
    fnox: string
    config: path
    local: record
    sources: path
    source_config: record
] {
    let version = (^$fnox --version | complete).stdout | str trim
    let sync_help = (^$fnox sync --help | complete).stdout
    let flags = [
        --global
        --provider
        --force
        --no-daemon
        --non-interactive
        --if-missing
    ]
    let unsupported = $flags | where {|flag| not ($sync_help | str contains $flag) }
    if ($unsupported | is-not-empty) {
        error make --unspanned {
            msg: $"($version | default 'fnox') at ($fnox) does not support sync ($unsupported | str join ', ')."
            help: "Upgrade fnox with mise from the dots checkout, then run secrets setup-shell and secrets refresh."
        }
    }

    mut problems = []
    let age = $local.providers.dots-age
    if $age.key_file? != null {
        if not ($age.key_file | path expand | path exists) {
            $problems = $problems | append $"Device age identity file ($age.key_file) is missing. Restore it, or import it with secrets setup --identity; the cache cannot be decrypted without it."
        }
    } else if $age.identity? != null {
        # The key is captured and discarded; only readability matters here.
        let identity = (
            ^$fnox --config $config --profile default --no-daemon --non-interactive get DOTS_AGE_IDENTITY
            | complete
        )
        if $identity.exit_code != 0 {
            $problems = $problems | append $"Device age identity could not be read from the OS credential store: ($identity.stderr | ansi strip | str trim). Unlock it; secrets setup never replaces an existing identity."
        }
    } else {
        $problems = $problems | append $"dots-age in ($config) has neither key_file nor identity. Run secrets setup."
    }

    let local_providers = $local.providers? | default {}
    let providers = $local_providers | merge ($source_config.providers? | default {})
    let secrets = $source_config.secrets? | default {} | transpose name secret
    for entry in $secrets {
        let secret = $entry.secret
        if ($secret | describe) !~ '^record' {
            $problems = $problems | append $"($entry.name) must be a table, e.g. { default = \"...\" } or { provider = \"...\", value = \"...\" }."
        } else if $secret.provider? == null and $secret.value? == null and $secret.default? == null {
            $problems = $problems | append $"($entry.name) has no provider, value or default."
        } else if $secret.provider? != null and $secret.provider not-in ($providers | columns) {
            let hint = if $secret.provider == "source-age" { " Run secrets init to add it." } else { "" }
            $problems = $problems | append $"($entry.name) uses provider ($secret.provider), which is not defined in ($sources).($hint)"
        }
    }
    let onepassword = $secrets | where {|entry|
        let provider = $entry.secret.provider?
        $provider != null and ($providers | get --optional $provider | get --optional type) == "1password"
    }
    if ($onepassword | is-not-empty) and (which op | is-empty) {
        $problems = $problems | append $"The 1Password CLI op is not on PATH; needed for ($onepassword.name | str join ', ')."
    } else if ($onepassword | is-not-empty) {
        $problems = $problems | append (check-onepassword-accounts $providers $onepassword)
    }
    if ($problems | is-not-empty) {
        error make --unspanned {
            msg: (
                $problems
                | each {|problem| $"- ($problem)" }
                | prepend "Secrets refresh cannot run yet:"
                | str join "\n"
            )
            help: "Nothing was changed. Fix the items above and rerun secrets refresh."
        }
    }
}

# Refresh the global cache; the native hook reloads it at the next prompt.
# All-or-nothing and repeatable: the live cache changes only after every step works.
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
        error make {msg: $"No enrolled device config with a dots-age provider at ($config). Run secrets setup first."}
    }

    let sources = (sources-path)
    if not ($sources | path exists) { error make {msg: $"Missing ($sources). Run secrets init to create your private sources.toml."} }
    let source_config = open $sources

    let entries = $source_config.secrets? | default {}
    let source_names = $entries | columns
    if "DOTS_AGE_IDENTITY" in $source_names {
        error make {msg: "DOTS_AGE_IDENTITY is reserved for the device key. Remove its entry from sources.toml."}
    }
    if "KETCH_HTTP_HEADERS" in $source_names {
        error make {msg: "KETCH_HTTP_HEADERS is derived during refresh. Remove its entry from sources.toml; keep the CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET sources."}
    }
    let fnox = (installed-tool fnox)
    refresh-preflight $fnox $config $local $sources $source_config

    let ketch_headers = "CF_ACCESS_CLIENT_ID" in $source_names and "CF_ACCESS_CLIENT_SECRET" in $source_names
    let names = if $ketch_headers {
        $source_names | append "KETCH_HTTP_HEADERS"
    } else { $source_names }

    let plaintext = ($entries | transpose name secret | where {|entry|
        $entry.secret.default? != null and $entry.secret.provider? == null and $entry.secret.value? == null
    } | get name)
    let sourced = $source_names | where {|name| $name not-in $plaintext }
    let removed = ($local.secrets? | default {} | transpose name secret | where {|entry|
        $entry.secret.provider? == "dots-age" and $entry.name not-in $names
    } | get name)
    let preserved = "The previous cache and shell environment were preserved."
    let fnox_args = [--profile default --no-daemon --non-interactive]

    # Interrupted runs can leave staging behind; no live refresh is this old.
    let directory = $config | path dirname
    # ls, not glob: Windows backslashes parse as glob escapes.
    let stales = ls --all $directory | where {|entry| ($entry.name | path basename) starts-with ".dots-refresh-" } | get name
    for stale in $stales {
        if ((date now) - (ls --directory $stale | get 0.modified)) > 1day {
            rm --recursive --force $stale
        }
    }

    # Keep the live cache usable while syncing; publish only after success.
    let staging = $directory | path join $".dots-refresh-(random uuid)"
    let pending = $staging | path join "config.toml"
    mkdir $staging
    try {
        if $nu.os-info.name == "linux" or (termux) {
            do --capture-errors { ^chmod 700 $staging }
        }
        cp $config $pending
        if ($sourced | is-not-empty) {
            with-env {FNOX_CONFIG_DIR: $staging} {
                (fnox-run $fnox "Syncing provider-backed secrets"
                    $"Check provider sign-in and the references in ($sources). ($preserved)"
                    [--config $sources ...$fnox_args --if-missing error sync --global --provider dots-age --force ...$sourced])
            } | ignore
        }
        for name in $plaintext {
            (
                $entries | get $name | get default | into string
                | fnox-run $fnox $"Encrypting the default for ($name)" $preserved
                    [--config $pending ...$fnox_args set $name --provider dots-age]
            ) | ignore
        }
        let updated = (open $pending)
        mut cache = $updated.secrets? | default {}
        for name in $sourced {
            let secret = $cache | get --optional $name
            # fnox keeps the remote reference plus an encrypted sync stanza.
            # Keep global shell keys local-only; remote references stay in sources.toml.
            if $secret.sync?.provider? != "dots-age" {
                error make {msg: $"fnox sync did not produce a local dots-age cache entry for ($name). ($preserved)"}
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
        $updated | upsert secrets ($cache | reject ...$removed) | to toml | save --force $pending
        if $ketch_headers {
            # Read the newly refreshed cache, never stale inherited shell tokens.
            let read = {|name|
                (fnox-run $fnox $"Reading refreshed ($name)" $preserved
                    [--config $pending ...$fnox_args get $name]).stdout | str trim
            }
            let headers = {
                "CF-Access-Client-Id": (do $read CF_ACCESS_CLIENT_ID)
                "CF-Access-Client-Secret": (do $read CF_ACCESS_CLIENT_SECRET)
            }
            let ketch = open ($dots | path join "ketch" "config.json")
            mut origins = {}
            for url in [$ketch.searxng_url $ketch.firecrawl_url] {
                let origin = $url | url parse | select scheme host port | url join
                $origins = $origins | upsert $origin $headers
            }
            (
                $origins | to json --raw
                | fnox-run $fnox "Encrypting KETCH_HTTP_HEADERS" $preserved
                    [--config $pending ...$fnox_args set KETCH_HTTP_HEADERS --provider dots-age]
            ) | ignore
        }
        if $nu.os-info.name == "linux" or (termux) {
            do --capture-errors { ^chmod 600 $pending }
        }
        mv --force $pending $config
    } catch {|err|
        rm --recursive --force $staging
        # Re-raise the original error with its source, help and fnox diagnostics.
        $err.raw
    }
    rm --recursive --force $staging
    print $"Refreshed ($names | length) cached secrets. fnox reloads at the next prompt; restart existing child processes to pick up changes."
}
