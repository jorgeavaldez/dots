# Linux bootstrap integration coverage. Only mise install/which is substituted;
# fnox, zoxide, symlinks, tic and the WezTerm terminfo download remain real.
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

def mock-mise-installs [f: record] {
    script $f mise '
def main --wrapped [...args: string] {
    (($args | to json --raw) + "\n") | save --raw --append $env.MISE_CALLS
    let actual = if ($args | first) == "--cd" { $args | skip 2 } else { $args }
    if $actual == ["install" "--yes"] {
        # MOCK: do not download/install the entire shared toolchain.
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
                        '/usr/bin/ln'
                        '-s'
                        ($f.home | path join 'missing-starship')
                        $starship
                    ]
                )
                let settings = $f.config | path join 'vicinae/settings.json'
                mkdir ($settings | path dirname)
                ok (
                    child $f [
                        '/usr/bin/ln'
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
            name: test_termux_is_rejected_before_changes
            run: {|fixture|
                let base = bootstrap-fixture $fixture
                for marker in [
                    {TERMUX_VERSION: '0.118.0'}
                    {PREFIX: '/data/data/com.termux/files/usr'}
                ] {
                    let f = $base | update env ($base.env | merge $marker)
                    let result = bootstrap $f ['--dry-run']
                    assert not ($result.exit_code == 0)
                    contains $result.stderr 'Termux'
                    absent $f.config
                }
            }
        }
    ]
}
