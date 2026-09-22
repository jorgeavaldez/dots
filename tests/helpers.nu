# Shared Linux integration fixtures. Never inherit the caller's credentials/config.
use std/assert

export def tools [] {
    assert equal $nu.os-info.name 'linux' 'These integration tests require Linux'
    mut tools = {}
    for spec in [
        [nu NU_BIN]
        [fnox FNOX_BIN]
        [age-keygen AGE_KEYGEN_BIN]
        [zoxide ZOXIDE_BIN]
    ] {
        let value = $env | get --optional $spec.1
        let executable = if $value != null { $value } else {
            let found = which $spec.0
            assert ($found | is-not-empty) $"Required tool missing: ($spec.0); set ($spec.1)"
            $found.0.path
        }
        assert ($executable | path exists) $"Required executable missing: ($executable)"
        let absolute = $executable | path expand
        $tools = $tools | insert $spec.0 $absolute
    }
    for executable in [
        /usr/bin/env
        /usr/bin/timeout
        /usr/bin/chmod
        /usr/bin/stat
        /usr/bin/readlink
        /usr/bin/ln
        /usr/bin/tic
    ] {
        assert ($executable | path exists) $"Required Linux utility missing: ($executable)"
    }
    $tools
}

export def fixture [tools: record] {
    assert ($env.TMPDIR? | is-not-empty) 'Set TMPDIR to the scratch directory'
    let root = mktemp --directory --tmpdir-path $env.TMPDIR 'dots-nu-tests.XXXXXXXX'
    let home = $root | path join home
    let config = $home | path join '.config'
    let bin = $home | path join '.local/bin'
    let tmp = $root | path join tmp
    mkdir $home $bin $tmp
    {
        root: $root
        home: $home
        config: $config
        bin: $bin
        tools: $tools
        repo: ($env.FILE_PWD | path dirname)
        env: {
            HOME: $home
            PATH: $"($bin):/usr/bin:/bin"
            XDG_CONFIG_HOME: $config
            XDG_DATA_HOME: ($home | path join '.local/share')
            XDG_CACHE_HOME: ($home | path join '.cache')
            XDG_STATE_HOME: ($home | path join '.local/state')
            TMPDIR: $tmp
            TERM: xterm-256color
        }
    }
}

# Absolute env/timeout and an explicit allowlist ensure a fresh child's startup
# observes fixture HOME/XDG/TMPDIR. with-env alone cannot provide that isolation.
export def child [
    f: record
    args: list<any>
    --input: string = ''
    --seconds: int = 90
] {
    assert ($args.0 | str starts-with '/') 'Child executable must be absolute'
    let assignments = $f.env | transpose key value | each {|entry| $"($entry.key)=($entry.value)" }
    cd $f.root
    $input | ^/usr/bin/env -i ...$assignments /usr/bin/timeout --kill-after=2s $"($seconds)s" ...$args | complete
}

export def ok [result: record] {
    assert equal $result.exit_code 0 ($result.stdout + $result.stderr)
}

export def nu [f: record, code: string, --fail] {
    let result = child $f [$f.tools.nu --no-config-file -c $code]
    if $fail { assert ($result.exit_code not-in [0 124 137]) 'Expected child failure, not success or timeout' } else { ok $result }
    $result
}

export def put [path: string, text: string] {
    mkdir ($path | path dirname)
    $text | save --raw --force $path
}

export def script [f: record, name: string, body: string] {
    let path = $f.bin | path join $name
    put $path ($"#!($f.tools.nu) --no-config-file\n" + $body + "\n")
    ok (^/usr/bin/chmod 755 $path | complete)
}

export def absent [path: string] {
    assert not ($path | path exists) $"Unexpected path: ($path)"
}

export def link [path: string, target: string] {
    assert equal ($path | path type) symlink
    let result = ^/usr/bin/readlink $path | complete
    ok $result
    assert equal ($result.stdout | str trim) $target
}

export def contains [text: string, needle: string] { assert ($text | str contains $needle) $"Missing ($needle) in: ($text)" }
export def lacks [text: string, needle: string] { assert not ($text | str contains $needle) $"Unexpected ($needle) in: ($text)" }
export def mode [path: string, expected: string] {
    let result = ^/usr/bin/stat -c '%a' $path | complete
    ok $result
    assert equal ($result.stdout | str trim) $expected
}
