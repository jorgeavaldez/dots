# Bootstrap integration coverage uses a mise shim; native selection is also
# exercised separately. fnox, zoxide, symlinks and tic remain real.
use std/assert
use helpers.nu [
    child
    ok
    script
    put
    absent
    link
    contains
    lacks
]

# Preserve the original suite's nondefault XDG layout, including its assertion
# that dry runs do not create XDG_CONFIG_HOME.
def bootstrap-fixture [f: record] {
    let config = $f.home | path join 'xdg-config'
    $f | merge {
        config: $config
        env: ($f.env | merge {
            XDG_CONFIG_HOME: $config
            XDG_DATA_HOME: ($f.home | path join 'xdg-data')
            XDG_CACHE_HOME: ($f.home | path join 'xdg-cache')
            XDG_STATE_HOME: ($f.home | path join 'xdg-state')
        })
    }
}

def bootstrap [f: record, args: list<any> = []] {
    child $f (
        [
            $f.tools.nu
            '--no-config-file'
            ($f.repo | path join 'bootstrap.nu')
        ]
        | append $args
    )
}

# Package layouts, not a blanket PREFIX root; sentinels need no native runtime.
def native-prefix [f: record] {
    let prefix = $f.root | path join native
    for binary in [
        bin/nu
        bin/node
        bin/npm
        bin/npx
        lib/go/bin/go
        lib/go/bin/gofmt
        lib/jvm/java-25-openjdk/bin/java
        lib/jvm/java-25-openjdk/bin/javac
        lib/jvm/java-25-openjdk/bin/jar
        lib/jvm/java-25-openjdk/bin/keytool
        lib/erlang/bin/erl
        lib/erlang/bin/erlc
        lib/erlang/bin/escript
        lib/erlang/bin/epmd
        opt/elixir/bin/elixir
        opt/elixir/bin/elixirc
        opt/elixir/bin/iex
        opt/elixir/bin/mix
    ] { put ($prefix | path join $binary) 'native-sentinel' }
    $prefix
}

def mock-mise-installs [f: record] {
    script $f mise '
def main --wrapped [...args: string] {
    let command = if ($args | first) == "--cd" { $args | skip 2 } else { $args }
    let actual = if ($command | first) == "--env" { $command | skip 2 } else { $command }
    if $actual == ["settings" "get" "enable_tools"] {
        let dir = $env.MISE_CONFIG_DIR? | default ($env.XDG_CONFIG_HOME | path join mise)
        let local = $dir | path join config.android.local.toml
        let config = if ($local | path exists) { $local } else { $dir | path join config.android.toml }
        print (open $config | get settings.enable_tools | sort | to json --raw)
        return
    }
    (($args | to json --raw) + "\n") | save --raw --append $env.MISE_CALLS
    if ($actual | first) == "install" {
        # MOCK: no toolchain download. Assert Android prerequisites are linked.
        if $env.TERMUX_VERSION? != null {
            if $actual != ["install" "--yes"] { error make {msg: "Selection must be owned by native mise settings"} }
            if $env.MISE_AUTO_ENV != "1" { error make {msg: "Android overlay inactive"} }
            if not (($env.MISE_CONFIG_DIR? | default ($env.XDG_CONFIG_HOME | path join mise) | path join "config.android.toml") | path exists) { error make {msg: "Overlay not linked before install"} }
            for native in [nu/bin/nu node/bin/node node/bin/npm node/bin/npx] {
                if not (($env.XDG_DATA_HOME | path join "dots/pkg" $native) | path exists) { error make {msg: "Native root missing"} }
            }
        } else if $actual != ["install" "--yes"] { error make {msg: "Desktop install changed"} }
        return
    }
    if ($actual | length) == 2 and $actual.0 == "which" and $actual.1 in ["fnox" "zoxide"] {
        print ($env | get $"($actual.1 | str uppercase)_BIN")
    } else {
        error make {msg: $"Unexpected mise invocation: ($actual | to json --raw)"}
    }
}
' | ignore
    $f | update env ($f.env | merge {
        FNOX_BIN: $f.tools.fnox
        ZOXIDE_BIN: $f.tools.zoxide
        MISE_CALLS: ($f.root | path join 'mise-calls')
    })
}

def starship-backups [f: record] {
    glob ($f.config | path join 'starship.toml.before-dots-*') | sort
}

export def cases [] {
    [
        {
            name: test_linux_dry_run_does_not_check_or_install_system_packages
            run: {|fixture|
                let f = bootstrap-fixture $fixture
                let result = bootstrap $f ['--dry-run']
                ok $result
                contains $result.stdout 'Linux prerequisites are assumed installed'
                lacks $result.stdout 'Will apply system packages'
                lacks $result.stdout 'through brew'
                absent $f.config
            }
        }
        {
            name: test_linux_full_bootstrap_uses_real_integrations_and_terminfo
            run: {|fixture|
                let f = mock-mise-installs (bootstrap-fixture $fixture)
                ok (bootstrap $f)
                assert equal (($f.home | path join '.gitconfig') | path type) 'symlink'
                link ($f.config | path join 'ov/config.yaml') ($f.repo | path join 'ov/config.yaml')
                assert equal (($f.home | path join 'xdg-data/nushell/zoxide.nu') | path type) 'file'
                contains (
                    open --raw (
                        $f.home
                        | path join 'xdg-data/nushell/vendor/autoload/fnox.nu'
                    )
                ) 'fnox'
                assert (glob ($f.home | path join '.terminfo/**/wezterm') | is-not-empty)
                lacks (open --raw ($f.root | path join 'mise-calls')) 'bootstrap'
            }
        }
        {
            name: test_managed_files_backups_and_local_state_survive_rerun
            run: {|fixture|
                let f = mock-mise-installs (bootstrap-fixture $fixture)
                let ssh = $f.home | path join '.ssh'
                let ssh_files = {config: "Host test\n  IdentityFile ~/.ssh/device_key\n", device_key: 'synthetic-preservation-sentinel'}
                for entry in ($ssh_files | transpose name content) {
                    put ($ssh | path join $entry.name) $entry.content
                }
                let plugins = $f.config | path join 'yazi/plugins/local.yazi'
                put ($plugins | path join 'main.lua') 'local plugin'
                put ($f.config | path join 'starship.toml') "# old prompt\n"
                put ($f.config | path join 'ov/config.yaml') "# local pager settings\n"
                put ($f.home | path join '.gitconfig') "[user]\nname = Local\n"
                ok (bootstrap $f)
                let expected = {
                    'starship.toml': 'starship.toml'
                    'zellij/config.kdl': 'zellij/config.kdl'
                    'vicinae/dots': 'vicinae'
                    'yazi/yazi.toml': 'yazi/yazi.toml'
                    'yazi/theme.toml': 'yazi/theme.toml'
                    'yazi/package.toml': 'yazi/package.toml'
                    'yazi/keymap.toml': 'yazi/keymap.toml'
                }
                for entry in ($expected | transpose destination source) {
                    link ($f.config | path join $entry.destination) ($f.repo | path join $entry.source)
                }
                for name in ['.vimrc' '.tmux.conf'] {
                    assert equal (($f.home | path join $name) | path expand) ($f.repo | path join $name)
                }
                assert not ((($f.config | path join 'yazi') | path type) == 'symlink')
                assert equal (open --raw ($plugins | path join 'main.lua')) 'local plugin'
                let settings = $f.config | path join 'vicinae/settings.json'
                assert not (($settings | path type) == 'symlink')
                assert equal (open --raw $settings | from json) {imports: ['dots/settings.json']}
                put $settings "{\"imports\": [\"dots/settings.json\"], \"local\": true}\n"
                let backups = starship-backups $f
                assert equal ($backups | length) 1
                assert equal (open --raw $backups.0) "# old prompt\n"
                assert equal (open --raw ($f.home | path join '.gitconfig.local')) "[user]\nname = Local\n"
                assert equal (open --raw ($f.config | path join 'ov/config.yaml')) "# local pager settings\n"
                ok (bootstrap $f)
                assert equal (starship-backups $f) $backups
                assert (open --raw $settings | from json | get local)
                assert equal (open --raw ($f.config | path join 'ov/config.yaml')) "# local pager settings\n"
                for entry in ($ssh_files | transpose name content) {
                    assert equal (open --raw ($ssh | path join $entry.name)) $entry.content
                }
                for name in ['.zshenv' '.zshrc' '.zprofile' '.ignore'] {
                    absent ($f.home | path join $name)
                }
            }
        }
        {
            name: test_late_directory_conflict_stops_before_install_or_links
            run: {|fixture|
                let f = mock-mise-installs (bootstrap-fixture $fixture)
                mkdir ($f.config | path join 'zellij/config.kdl')
                let result = bootstrap $f
                assert not ($result.exit_code == 0)
                contains $result.stderr 'Config conflict'
                absent ($f.root | path join 'mise-calls')
                absent ($f.config | path join 'mise')
            }
        }
        {
            name: test_git_backup_collision_stops_before_install
            run: {|fixture|
                let f = mock-mise-installs (bootstrap-fixture $fixture)
                for name in ['.gitconfig' '.gitconfig.local'] {
                    put ($f.home | path join $name) $"keep ($name)"
                }
                let result = bootstrap $f
                assert not ($result.exit_code == 0)
                contains $result.stderr 'already exists'
                absent ($f.root | path join 'mise-calls')
                assert equal (open --raw ($f.home | path join '.gitconfig')) 'keep .gitconfig'
            }
        }
        {
            name: test_dangling_links_are_backed_up_but_mutable_vicinae_is_preserved
            run: {|fixture|
                let f = mock-mise-installs (bootstrap-fixture $fixture)
                mkdir $f.config
                let starship = $f.config | path join 'starship.toml'
                ok (
                    child $f [
                        $f.tools.ln
                        '-s'
                        ($f.home | path join 'missing-starship')
                        $starship
                    ]
                )
                let settings = $f.config | path join 'vicinae/settings.json'
                mkdir ($settings | path dirname)
                ok (
                    child $f [
                        $f.tools.ln
                        '-s'
                        ($f.home | path join 'missing-local-settings')
                        $settings
                    ]
                )
                ok (bootstrap $f)
                assert equal ($starship | path expand) ($f.repo | path join 'starship.toml')
                let backups = starship-backups $f
                assert equal ($backups | length) 1
                link $backups.0 ($f.home | path join 'missing-starship')
                link $settings ($f.home | path join 'missing-local-settings')
                assert not ($settings | path exists)
            }
        }
        {
            name: test_explicit_config_overrides_are_respected
            run: {|fixture|
                let base = mock-mise-installs (bootstrap-fixture $fixture)
                let f = $base | update env ($base.env | merge {
                    MISE_CONFIG_DIR: ($base.home | path join 'custom-mise')
                    MISE_GLOBAL_CONFIG_FILE: ($base.home | path join 'global-mise.toml')
                    STARSHIP_CONFIG: ($base.home | path join 'custom-starship.toml')
                    YAZI_CONFIG_HOME: ($base.home | path join 'custom-yazi')
                })
                ok (bootstrap $f)
                let expected = {
                    'custom-mise/tasks': 'mise/tasks'
                    'global-mise.toml': 'mise/config.toml'
                    'custom-starship.toml': 'starship.toml'
                    'custom-yazi/keymap.toml': 'yazi/keymap.toml'
                }
                for entry in ($expected | transpose target source) {
                    assert equal (($f.home | path join $entry.target) | path expand) ($f.repo | path join $entry.source)
                }
            }
        }
        {
            name: test_android_bootstrap_links_overlay_native_root_and_preserves_reruns
            run: {|fixture|
                let base = mock-mise-installs (bootstrap-fixture $fixture)
                let prefix = native-prefix $base
                let mise_dir = $base.home | path join custom-mise
                let f = $base | update env (
                    $base.env
                    | merge {TERMUX_VERSION: 'test' PREFIX: $prefix MISE_CONFIG_DIR: $mise_dir}
                )
                # The retained wrapper needs its seed binary on the second run.
                script $f jj 'def --wrapped main [...args: string] { print ($env.XDG_CONFIG_HOME | path join jj/config.toml) }'
                mkdir ($f.home | path join .local/libexec)
                mv ($f.bin | path join jj) ($f.home | path join .local/libexec/jj)
                ok (bootstrap $f ['--dry-run'])
                absent $mise_dir
                ok (bootstrap $f)
                link ($mise_dir | path join config.toml) ($f.repo | path join mise/config.toml)
                link ($mise_dir | path join config.android.toml) ($f.repo | path join termux/config.android.toml)
                link ($f.home | path join .local/bin/jj) ($f.repo | path join termux/jj-wrapper.sh)
                link ($f.home | path join xdg-data/dots/pkg/nu/bin/nu) ($prefix | path join bin/nu)
                for binary in [node npm npx] {
                    link ($f.home | path join xdg-data/dots/pkg/node/bin $binary) ($prefix | path join bin $binary)
                }
                link ($f.home | path join xdg-data/dots/pkg/go) ($prefix | path join lib/go)
                for tool in [java erlang elixir] {
                    absent ($f.home | path join xdg-data/dots/pkg $tool)
                }
                assert (($f.home | path join xdg-data/nushell/zoxide.nu) | path exists)
                contains (
                    open --raw ($f.home | path join xdg-data/nushell/vendor/autoload/fnox.nu)
                ) 'fnox'
                absent ($f.home | path join .terminfo)
                absent ($f.config | path join vicinae)
                ok (bootstrap $f)
                assert equal (glob ($mise_dir | path join '*.before-dots-*')) []
            }
        }
        {
            name: test_android_overlay_conflict_stops_before_install
            run: {|fixture|
                let base = mock-mise-installs (bootstrap-fixture $fixture)
                let prefix = native-prefix $base
                let f = $base | update env ($base.env | merge {TERMUX_VERSION: 'test' PREFIX: $prefix})
                for conflict in [
                    ($f.config | path join mise/config.android.toml)
                    ($f.home | path join xdg-data/dots/pkg/nu/bin/nu)
                    ($f.home | path join xdg-data/dots/pkg/go)
                ] {
                    mkdir $conflict
                    let result = bootstrap $f
                    assert ($result.exit_code != 0)
                    contains $result.stderr 'Config conflict'
                    absent ($f.root | path join mise-calls)
                    absent ($f.config | path join mise/config.toml)
                    rm --recursive $conflict
                }
            }
        }
        {
            name: test_android_explicit_overlay_disabling_overrides_fail_without_changes
            run: {|fixture|
                let base = bootstrap-fixture $fixture
                for override in [
                    {
                        MISE_GLOBAL_CONFIG_FILE: ($base.home | path join explicit.toml)
                    }
                    {MISE_AUTO_ENV: '0'}
                ] {
                    let f = $base | update env ($base.env | merge {TERMUX_VERSION: 'test'} | merge $override)
                    let result = bootstrap $f ['--dry-run']
                    assert ($result.exit_code != 0)
                    contains $result.stderr 'override'
                    absent $f.config
                }
            }
        }
        {
            name: test_android_missing_native_nu_stops_before_install
            run: {|fixture|
                let base = mock-mise-installs (bootstrap-fixture $fixture)
                let prefix = native-prefix $base
                rm ($prefix | path join bin/nu)
                let f = $base | update env ($base.env | merge {TERMUX_VERSION: 'test' PREFIX: $prefix})
                let result = bootstrap $f
                assert ($result.exit_code != 0)
                contains $result.stderr 'native/bin/nu'
                absent ($f.root | path join mise-calls)
                absent $f.config
            }
        }
        {
            name: test_android_missing_native_language_root_stops_before_install
            run: {|fixture|
                let base = mock-mise-installs (bootstrap-fixture $fixture)
                let prefix = native-prefix $base
                let f = $base | update env ($base.env | merge {TERMUX_VERSION: 'test' PREFIX: $prefix})
                put ($f.config | path join mise/config.android.local.toml) '[settings]
enable_tools = ["nu", "node", "fnox", "age", "zoxide", "carapace", "java", "erlang", "elixir"]
'
                for root in [lib/jvm/java-25-openjdk lib/erlang opt/elixir] {
                    let source = $prefix | path join $root
                    mv $source $"($source).saved"
                    let result = bootstrap $f
                    assert ($result.exit_code != 0)
                    contains $result.stderr $root
                    absent ($f.root | path join mise-calls)
                    absent ($f.config | path join mise/config.toml)
                    mv $"($source).saved" $source
                }
            }
        }
        {
            name: test_android_local_selection_controls_native_packages_and_roots
            run: {|fixture|
                let base = mock-mise-installs (bootstrap-fixture $fixture)
                let prefix = native-prefix $base
                let f = $base | update env ($base.env | merge {TERMUX_VERSION: 'test' PREFIX: $prefix})
                put ($f.config | path join mise/config.android.local.toml) '[settings]
enable_tools = ["nu", "node", "fnox", "age", "zoxide", "carapace", "java"]
'
                let packages = bootstrap $f ['--android-packages']
                ok $packages
                assert equal ($packages.stdout | lines) [openjdk-25]
                rm --recursive ($prefix | path join lib/go) ($prefix | path join lib/erlang) ($prefix | path join opt/elixir)
                ok (bootstrap $f)
                link ($f.home | path join xdg-data/dots/pkg/java) ($prefix | path join lib/jvm/java-25-openjdk)
                for tool in [go erlang elixir] { absent ($f.home | path join xdg-data/dots/pkg $tool) }
                let project = $f.root | path join project
                put ($project | path join mise.toml) (open --raw ($f.repo | path join mise/config.toml))
                let effective = child ($f | update env ($f.env | merge {MISE_AUTO_ENV: '1'})) [
                    $f.tools.mise
                    --cd
                    $project
                    --env
                    android
                    settings
                    get
                    enable_tools
                ]
                ok $effective
                assert equal ($effective.stdout | from json) [
                    age
                    carapace
                    fnox
                    java
                    node
                    nu
                    zoxide
                ]
            }
        }
        {
            name: test_android_detects_musl_prefix_and_reports_missing_native_seed
            run: {|fixture|
                let base = mock-mise-installs (bootstrap-fixture $fixture)
                let f = $base | update env ($base.env | merge {PREFIX: '/missing/com.termux/files/usr'})
                let result = bootstrap $f ['--dry-run']
                assert ($result.exit_code != 0)
                contains $result.stderr 'Missing source'
                absent $f.config
            }
        }
    ]
}
