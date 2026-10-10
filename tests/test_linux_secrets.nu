# Real Nu/fnox/age integration, synthetic inputs and isolated HOME only.
use std/assert
use helpers.nu [
    child
    ok
    script
    put
    absent
    contains
    lacks
    mode
]

# Discovery only, never host mise or 1Password. A sentinel proves op was unused.
def secret-fixture [base: record] {
    let config = $base.config | path join 'fnox/config.toml'
    let f = $base | merge {
        config: $config
        env: ($base.env | merge {FNOX_CONFIG_DIR: ($config | path dirname) FNOX_NO_DAEMON: '1'})
    }
    discovery $f $f.tools
    script $f op 'def --wrapped main [...args: string] { touch ($env.HOME | path join "op-calls"); exit 91 }'
    $f
}

def discovery [f: record, tools: record] {
    let encoded = $tools | to json -r | to nuon
    script $f mise (
        'def --wrapped main [...args: string] {
            if $env.TERMUX_VERSION? != null and $env.MISE_AUTO_ENV? != "1" { error make {msg: "Android overlay missing during explicit tool resolution"} }
            let tools = @TOOLS@ | from json
            print ($tools | get ($args | last))
        }'
        | str replace '@TOOLS@' $encoded
    )
}

def secrets [f: record, code: string, --fail] {
    let module = $f.repo | path join 'nushell/secrets.nu' | to nuon
    let result = child $f [$f.tools.nu -n -c $'use ($module); ($code)']
    if $fail { assert ($result.exit_code not-in [0 124 137]) 'Expected secrets failure, not success or timeout' } else { ok $result }
    $result
}

def fnox [f: record, args: list<any>, --input: string = ''] {
    let result = child $f ([$f.tools.fnox --no-daemon --non-interactive] | append $args) --input $input
    ok $result
    $result
}

def key [f: record] {
    $f.config | path dirname | path join age.txt
}
def op-absent [f: record] { absent ($f.home | path join op-calls) }
def snapshot [f: record] {
    [
        (open --raw (key $f))
        (open --raw $f.config)
    ]
}
def no-staging [f: record, pattern: string] { assert equal (glob ($f.config | path dirname | path join $pattern)) [] }
def generate [f: record, path: string] { ok (child $f [$f.tools.age-keygen -o $path]) }

def fail-chmod [f: record, target: string, --substring] {
    let operator = if $substring { 'contains' } else { 'ends-with' }
    script $f chmod ('def --wrapped main [...args: string] {
    if ($args | last | str @OPERATOR@ @TARGET@) { exit 73 }
    exec @CHMOD@ ...$args
}' | str replace '@CHMOD@' ($f.tools.chmod | to nuon) | str replace '@OPERATOR@' $operator | str replace '@TARGET@' ($target | to nuon))
}

# A background job transports a complete result, including unexpected Nu errors.
# GNU timeout owns the child process group and kills descendants on deadline.
# Finally always releases and collects BEFORE the fixture may be removed.
def concurrent [f: record] {
    let entered = $f.home | path join entered
    let release = $f.home | path join release
    let wrapper = $f.bin | path join paused-age-keygen
    script $f paused-age-keygen ('def --wrapped main [...args: string] {
    let entered = @ENTERED@
    let release = @RELEASE@
    if "-o" in $args and not ($entered | path exists) {
        touch $entered
        let deadline = (date now) + 15sec
        while not ($release | path exists) {
            if (date now) > $deadline { exit 90 }
            sleep 10ms
        }
    }
    exec @REAL@ ...$args
}' | str replace '@ENTERED@' ($entered | to nuon) | str replace '@RELEASE@' ($release | to nuon) | str replace '@REAL@' ($f.tools.age-keygen | to nuon))
    discovery $f ($f.tools | update age-keygen $wrapper)
    let module = $f.repo | path join 'nushell/secrets.nu' | to nuon
    let args = [$f.tools.nu -n -c $'use ($module); secrets setup']
    let id = job spawn {
        let result = try { child $f $args --seconds 20 } catch {|err| {exit_code: 125 stdout: '' stderr: $err.msg} }
        $result | job send 0 --tag 715
    }

    try {
        let deadline = (date now) + 10sec
        while not ($entered | path exists) and (date now) < $deadline { sleep 10ms }
        assert ($entered | path exists) 'First enrollment did not reach key generation'
        let lock = $f.config | path dirname | path join '.dots-setup.lock'
        mode $lock '700'
        let contender = secrets $f 'secrets setup' --fail
        assert equal ($lock | path type) dir 'Contender removed the owner lock'
        contains $contender.stderr 'enrollment lock'
        absent $f.config
    } finally {
        touch $release
        # Longer than timeout + kill-after, including the error path above.
        let winner = job recv --tag 715 --timeout 25sec
        let deadline = (date now) + 2sec
        while ($id in (job list | get id)) and (date now) < $deadline { sleep 10ms }
        assert not ($id in (job list | get id)) 'Enrollment job did not terminate'
        ok $winner
    }
    absent ($f.config | path dirname | path join '.dots-setup.lock')
    fnox $f [set --global CONCURRENT --provider dots-age] --input synthetic-race | ignore
    let before = snapshot $f
    secrets $f 'secrets setup' | ignore
    assert equal (snapshot $f) $before
    assert equal ((fnox $f [get CONCURRENT]).stdout | str trim) synthetic-race
    op-absent $f
}

export def cases [] {
    [
        {
            name: test_android_enrollment_refresh_and_hook_use_private_files
            run: {|base|
                let f = secret-fixture ($base | update env ($base.env | merge {TERMUX_VERSION: 'test'}))
                secrets $f 'secrets setup; secrets setup-shell' | ignore
                let sources = $f.config | path dirname | path join sources.toml
                put $sources '[secrets]
ANDROID_TEST = { default = "synthetic-android" }
'
                secrets $f 'secrets refresh' | ignore
                mode $f.config '600'
                mode (key $f) '600'
                mode ($f.config | path dirname) '700'
                let before = snapshot $f
                secrets $f 'secrets setup' | ignore
                assert equal (snapshot $f) $before
                let hook = $f.home | path join '.local/share/nushell/vendor/autoload/fnox.nu'
                secrets $f $'source ($hook | to nuon); if $env.ANDROID_TEST? != "synthetic-android" { error make {msg: "Android hook did not load"} }' | ignore
                lacks (open --raw $f.config) synthetic-android
                op-absent $f
            }
        }
        {
            name: test_local_encrypted_sources_refresh_without_op
            run: {|base|
                for overlay in [
                    {}
                    {TERMUX_VERSION: 'test'}
                ] {
                    let f = secret-fixture ($base | update env ($base.env | merge $overlay))
                    secrets $f 'secrets setup' | ignore
                    let sources = $f.config | path dirname | path join sources.toml
                    assert equal (open $sources).providers.source-age (open $f.config).providers.dots-age
                    let before = open --raw $f.config
                    let result = secrets $f '"synthetic-local" | secrets local LOCAL_KEY'
                    lacks ($result.stdout + $result.stderr) synthetic-local
                    assert equal (open --raw $f.config) $before
                    assert equal (open $sources).secrets.LOCAL_KEY.provider source-age
                    lacks (open --raw $sources) synthetic-local
                    mode $sources '600'
                    let settings = open $sources
                    $settings | upsert secrets.VAULT_PATH {default: '/synthetic/vault'} | to toml | save --force $sources
                    secrets $f 'secrets refresh' | ignore
                    assert equal ((fnox $f [get LOCAL_KEY]).stdout | str trim) synthetic-local
                    assert equal ((fnox $f [get VAULT_PATH]).stdout | str trim) /synthetic/vault
                    secrets $f '"synthetic-rotated" | secrets local LOCAL_KEY; secrets refresh' | ignore
                    assert equal ((fnox $f [get LOCAL_KEY]).stdout | str trim) synthetic-rotated
                    lacks (open --raw $sources) synthetic-rotated
                    lacks (open --raw $f.config) synthetic-rotated
                    open $sources | reject secrets.LOCAL_KEY | to toml | save --force $sources
                    secrets $f 'secrets refresh' | ignore
                    assert not ('LOCAL_KEY' in ((open $f.config).secrets | columns))
                    op-absent $f
                }
            }
        }
        {
            name: test_ketch_headers_refresh_tracks_sources_rotation_and_removal
            run: {|base|
                let f = secret-fixture ($base | update env ($base.env | merge {
                    CF_ACCESS_CLIENT_ID: 'stale-inherited-id'
                    CF_ACCESS_CLIENT_SECRET: 'stale-inherited-secret'
                }))
                secrets $f 'secrets setup; "synthetic-id" | secrets local CF_ACCESS_CLIENT_ID; "synthetic-secret" | secrets local CF_ACCESS_CLIENT_SECRET' | ignore
                let sources = $f.config | path dirname | path join sources.toml
                let source_before = open --raw $sources
                let result = secrets $f 'secrets refresh --if-enrolled'
                lacks ($result.stdout + $result.stderr) synthetic-secret
                assert equal (open --raw $sources) $source_before
                assert equal (open $f.config).secrets.KETCH_HTTP_HEADERS.provider dots-age
                lacks (open --raw $f.config) synthetic-secret
                let ketch = open ($f.repo | path join ketch/config.json)
                let origins = [$ketch.searxng_url $ketch.firecrawl_url] | each {|url| $url | url parse | select scheme host port | url join } | uniq | sort
                let headers = (fnox $f [get KETCH_HTTP_HEADERS]).stdout | from json
                assert equal ($headers | columns | sort) $origins
                for origin in $origins {
                    assert equal ($headers | get $origin) {
                        'CF-Access-Client-Id': 'synthetic-id'
                        'CF-Access-Client-Secret': 'synthetic-secret'
                    }
                }
                secrets $f '"synthetic-rotated-secret" | secrets local CF_ACCESS_CLIENT_SECRET; secrets refresh' | ignore
                let rotated = (fnox $f [get KETCH_HTTP_HEADERS]).stdout | from json
                for origin in $origins {
                    assert equal ($rotated | get $origin | get CF-Access-Client-Secret) synthetic-rotated-secret
                }
                lacks (open --raw $f.config) synthetic-rotated-secret

                # A failed derived-secret write must not publish any staged changes.
                let before = open --raw $f.config
                script $f failing-ketch-fnox ('def --wrapped main [...args: string] {
    if "set" in $args and "KETCH_HTTP_HEADERS" in $args { exit 73 }
    exec @FNOX@ ...$args
}' | str replace '@FNOX@' ($f.tools.fnox | to nuon))
                discovery $f ($f.tools | update fnox ($f.bin | path join failing-ketch-fnox))
                secrets $f 'secrets refresh' --fail | ignore
                assert equal (open --raw $f.config) $before
                no-staging $f '.dots-refresh-*'
                discovery $f $f.tools

                # Losing either dependency removes stale derived credentials.
                open $sources | reject secrets.CF_ACCESS_CLIENT_SECRET | to toml | save --force $sources
                secrets $f 'secrets refresh' | ignore
                assert not ('KETCH_HTTP_HEADERS' in ((open $f.config).secrets | columns))
                assert equal ((fnox $f [get CF_ACCESS_CLIENT_ID]).stdout | str trim) synthetic-id
                op-absent $f
            }
        }
        {
            name: test_refresh_if_enrolled_skips_unenrolled_without_creating_state
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets refresh --if-enrolled' | ignore
                absent ($f.config | path dirname)
                secrets $f 'secrets refresh' --fail | ignore
                absent ($f.config | path dirname)
                put $f.config '[providers.other]
type = "age"
recipients = []
'
                let before = open --raw $f.config
                secrets $f 'secrets refresh --if-enrolled' | ignore
                assert equal (open --raw $f.config) $before
                absent ($f.config | path dirname | path join sources.toml)
            }
        }
        {
            name: test_setup_adds_local_provider_without_replacing_source_entries
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup' | ignore
                let sources = $f.config | path dirname | path join sources.toml
                put $sources '# Keep my comments and defaults.
[secrets]
VAULT_PATH = { default = "/synthetic/vault" }
'
                let before = snapshot $f
                secrets $f 'secrets setup' | ignore
                assert equal (snapshot $f) $before
                contains (open --raw $sources) '# Keep my comments and defaults.'
                assert equal (open $sources).secrets.VAULT_PATH.default /synthetic/vault
                assert equal (open $sources).providers.source-age (open $f.config).providers.dots-age
                let enrolled = open --raw $sources
                secrets $f 'secrets setup; secrets init' | ignore
                assert equal (open --raw $sources) $enrolled
                op-absent $f
            }
        }
        {
            name: test_local_requires_enrollment_rejects_identity_and_propagates_fnox_failure
            run: {|base|
                let f = secret-fixture $base
                secrets $f '"synthetic-local" | secrets local LOCAL_KEY' --fail | ignore
                absent ($f.config | path dirname)
                secrets $f 'secrets setup' | ignore
                let sources = $f.config | path dirname | path join sources.toml
                let before = open --raw $sources
                for name in [DOTS_AGE_IDENTITY KETCH_HTTP_HEADERS] {
                    secrets $f $'"synthetic-local" | secrets local ($name)' --fail | ignore
                    assert equal (open --raw $sources) $before
                }
                script $f failing-fnox 'def --wrapped main [...args: string] { exit 73 }'
                discovery $f ($f.tools | update fnox ($f.bin | path join failing-fnox))
                let result = secrets $f '"synthetic-local" | secrets local LOCAL_KEY' --fail
                assert equal $result.exit_code 73
                lacks $result.stdout 'Stored LOCAL_KEY'
                assert equal (open --raw $sources) $before
                op-absent $f
            }
        }
        {
            name: test_concurrent_setup_rejects_contender_and_preserves_winner
            run: {|base| concurrent (secret-fixture $base) }
        }
        {
            name: test_existing_recipient_mismatch_is_not_replaced
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup' | ignore
                rm (key $f)
                generate $f (key $f)
                let before = snapshot $f
                secrets $f 'secrets setup' --fail | ignore
                assert equal (snapshot $f) $before
                absent ($f.config | path dirname | path join '.dots-setup.lock')
            }
        }
        {
            name: test_init_chmod_failure_stops_before_template_write
            run: {|base|
                let f = secret-fixture $base
                fail-chmod $f '/fnox'
                secrets $f 'secrets init' --fail | ignore
                absent ($f.config | path dirname | path join sources.toml)
            }
        }
        {
            name: test_chmod_failure_stops_before_identity_copy
            run: {|base|
                let f = secret-fixture $base
                let source = $f.home | path join import.txt
                generate $f $source
                fail-chmod $f '/fnox'
                secrets $f $'secrets setup --identity ($source | to nuon)' --fail | ignore
                absent $f.config
                no-staging $f '**/age.txt'
            }
        }
        {
            name: test_staging_chmod_failure_cleans_up_before_import
            run: {|base|
                let f = secret-fixture $base
                let source = $f.home | path join import.txt
                generate $f $source
                fail-chmod $f '.dots-enroll-' --substring
                secrets $f $'secrets setup --identity ($source | to nuon)' --fail | ignore
                no-staging $f '**/age.txt'
                no-staging $f '.dots-enroll-*'
            }
        }
        {
            name: test_chmod_failure_prevents_publication
            run: {|base|
                let f = secret-fixture $base
                for filename in [age.txt config.toml] {
                    fail-chmod $f $filename
                    secrets $f 'secrets setup' --fail | ignore
                    absent $f.config
                    absent (key $f)
                    no-staging $f '.dots-enroll-*'
                }
            }
        }
        {
            name: test_refresh_chmod_failure_preserves_cache_and_cleans_staging
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup' | ignore
                let before = open --raw $f.config
                for target in ['.dots-refresh-' config.toml] {
                    fail-chmod $f $target --substring
                    secrets $f 'secrets refresh' --fail | ignore
                    assert equal (open --raw $f.config) $before
                    no-staging $f '.dots-refresh-*'
                }
            }
        }
        {
            name: test_linux_enrollment_is_private_idempotent_and_works_without_op
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup' | ignore
                let settings = open $f.config
                let provider = $settings.providers.dots-age
                assert equal $provider.type age
                mode $provider.key_file '600'
                mode $f.config '600'
                mode ($f.config | path dirname) '700'
                assert not ('dots-keychain' in $settings.providers)
                fnox $f [set --global TEST_DOTS_SECRET --provider dots-age] --input synthetic-test-only | ignore
                let before = snapshot $f
                secrets $f 'secrets setup' | ignore
                assert equal (snapshot $f) $before
                assert equal ((fnox $f [get TEST_DOTS_SECRET]).stdout | str trim) synthetic-test-only
                lacks (open --raw $f.config) synthetic-test-only
                assert equal (
                    fnox $f [
                        exec
                        --
                        $f.tools.sh
                        -c
                        'test "$TEST_DOTS_SECRET" = synthetic-test-only'
                    ]
                ).stdout ''
                lacks (open --raw $f.config) AGE-SECRET-KEY-
                op-absent $f
            }
        }
        {
            name: test_native_hook_loads_local_cache_without_op
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup; secrets setup-shell' | ignore
                fnox $f [set --global TEST_DOTS_SECRET --provider dots-age] --input synthetic-hook | ignore
                let hook = $f.home | path join '.local/share/nushell/vendor/autoload/fnox.nu'
                assert ($hook | path exists)
                let result = secrets $f $'source ($hook | to nuon); if $env.TEST_DOTS_SECRET? != "synthetic-hook" { error make {msg: "hook did not load cache"} }; if $env.DOTS_AGE_IDENTITY? != null { error make {msg: "identity exported"} }'
                lacks ($result.stdout + $result.stderr) synthetic-hook
                op-absent $f
            }
        }
        {
            name: test_native_hook_without_cache_is_noop
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup-shell' | ignore
                let hook = $f.home | path join '.local/share/nushell/vendor/autoload/fnox.nu'
                let before = open --raw $hook
                # The native hook calls its embedded real fnox path. No dynamic mise
                # resolution, enrollment, or 1Password is allowed at shell startup.
                for name in [mise age-keygen op] {
                    script $f $name 'def --wrapped main [...args: string] { touch ($env.HOME | path join "unexpected-tool"); exit 73 }'
                }
                let result = secrets $f $'source ($hook | to nuon); if $env.TEST_DOTS_SECRET? != null { error make {msg: "unexpected secret"} }; if $env.DOTS_AGE_IDENTITY? != null { error make {msg: "identity exported"} }'
                assert equal $result.stdout ''
                assert equal $result.stderr ''
                assert equal (open --raw $hook) $before
                absent ($f.home | path join unexpected-tool)
                absent $f.config
                absent (key $f)
                op-absent $f
            }
        }
        {
            name: test_refresh_uses_real_age_source_and_failed_op_preserves_cache
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup' | ignore
                let sources = $f.config | path dirname | path join sources.toml
                put $sources (open --raw $f.config | str replace --all dots-age source-age)
                fnox $f [
                    --config
                    $sources
                    set
                    TEST_REFRESH
                    --provider
                    source-age
                ] --input synthetic-refresh | ignore
                secrets $f 'secrets refresh' | ignore
                assert equal ((fnox $f [get TEST_REFRESH]).stdout | str trim) synthetic-refresh
                mode $f.config '600'
                op-absent $f
                let before = open --raw $f.config
                put $sources "[providers.onepassword]\ntype=\"1password\"\n[secrets]\nTEST_REFRESH={provider=\"onepassword\",value=\"op://Fake/Absent/credential\"}\n"
                secrets $f 'secrets refresh' --fail | ignore
                assert (($f.home | path join op-calls) | path exists)
                assert equal (open --raw $f.config) $before
                assert equal ((fnox $f [get TEST_REFRESH]).stdout | str trim) synthetic-refresh
                no-staging $f '.dots-refresh-*'
            }
        }
        {
            name: test_refresh_encrypts_plaintext_defaults_alongside_provider_sources
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'secrets setup' | ignore
                let sources = $f.config | path dirname | path join sources.toml
                put $sources (open --raw $f.config | str replace --all dots-age source-age)
                fnox $f [
                    --config
                    $sources
                    set
                    REMOTE
                    --provider
                    source-age
                ] --input synthetic-remote | ignore
                let source_config = open $sources
                $source_config | update secrets (
                    $source_config.secrets
                    | upsert LOCAL {default: 'https://example.invalid/one'}
                ) | to toml | save --force $sources
                secrets $f 'secrets refresh' | ignore
                assert equal ((fnox $f [get REMOTE]).stdout | str trim) synthetic-remote
                assert equal ((fnox $f [get LOCAL]).stdout | str trim) 'https://example.invalid/one'
                lacks (open --raw $f.config) 'https://example.invalid/one'
                op-absent $f

                let before = open --raw $f.config
                put $sources '[secrets]
LOCAL = { default = "https://example.invalid/two" }
BAD = { provider = "missing", value = "invalid" }
'
                secrets $f 'secrets refresh' --fail | ignore
                assert equal (open --raw $f.config) $before
                no-staging $f '.dots-refresh-*'

                put $sources '[secrets]
LOCAL = { default = "https://example.invalid/two" }
'
                secrets $f 'secrets refresh' | ignore
                assert equal ((fnox $f [get LOCAL]).stdout | str trim) 'https://example.invalid/two'
                assert not ('REMOTE' in ((open $f.config).secrets | columns))
                lacks (open --raw $f.config) 'https://example.invalid/two'
                op-absent $f
            }
        }
        {
            name: test_init_creates_private_sources_and_has_no_module_side_effects
            run: {|base|
                let f = secret-fixture $base
                secrets $f 'null' | ignore
                absent ($f.config | path dirname)
                secrets $f 'secrets init' | ignore
                mode ($f.config | path dirname | path join sources.toml) '600'
                mode ($f.config | path dirname) '700'
            }
        }
        {
            name: test_import_is_explicit_validated_and_never_replaces_identity
            run: {|base|
                let f = secret-fixture $base
                let source = $f.home | path join import.txt
                generate $f $source
                secrets $f $'secrets setup --identity ($source | to nuon)' | ignore
                assert equal (open --raw (key $f)) (open --raw $source)
                let before = snapshot $f
                secrets $f $'secrets setup --identity ($source | to nuon)' --fail | ignore
                assert equal (snapshot $f) $before
            }
        }
        {
            name: test_existing_unrelated_config_and_missing_key_are_not_replaced
            run: {|base|
                let f = secret-fixture $base
                put $f.config "[providers.other]\ntype=\"age\"\nrecipients=[]\n"
                let before = open --raw $f.config
                secrets $f 'secrets setup' --fail | ignore
                assert equal (open --raw $f.config) $before
                rm $f.config
                secrets $f 'secrets setup' | ignore
                rm (key $f)
                let before = open --raw $f.config
                secrets $f 'secrets setup' --fail | ignore
                absent (key $f)
                assert equal (open --raw $f.config) $before
            }
        }
        {
            name: test_orphan_identity_requires_explicit_import
            run: {|base|
                let f = secret-fixture $base
                mkdir ($f.config | path dirname)
                generate $f (key $f)
                let before = open --raw (key $f)
                secrets $f 'secrets setup' --fail | ignore
                absent $f.config
                secrets $f $'secrets setup --identity (key $f | to nuon)' | ignore
                assert equal (open --raw (key $f)) $before
            }
        }
        {
            name: test_invalid_import_leaves_no_config_or_identity
            run: {|base|
                let f = secret-fixture $base
                let source = $f.home | path join invalid.txt
                put $source 'not an age key'
                secrets $f $'secrets setup --identity ($source | to nuon)' --fail | ignore
                absent $f.config
                absent (key $f)
            }
        }
    ]
}
