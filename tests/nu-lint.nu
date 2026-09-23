#!/usr/bin/env nu
# Focused tool probe; runs separately from the bootstrap integration suite.
use std/assert

def invoke [f: record, args: list<string>] {
    let result = with-env {TMPDIR: $f.temp} {
        ^$nu.current-exe --no-config-file $f.lint ...$args | complete
    }
    assert equal (glob ($f.temp | path join '*') | length) 0 'Leaked lint sandbox'
    $result
}

def succeeds [result: record] {
    assert equal $result.exit_code 0 $"Unexpected failure: ($result.stderr)($result.stdout)"
}

def fails [result: record] {
    assert ($result.exit_code != 0) 'Expected nonzero exit'
}

# Nu-only executable stubs are limited to fault injection and isolation probes.
def stub [f: record, name: string, body: string] {
    let file = $f.bin | path join $name
    $"#!($nu.current-exe) --no-config-file\n($body)\n" | save --force $file
    let result = ^chmod +x $file | complete
    succeeds $result
}

def main [] {
    let original = $env.PWD
    let lint = $env.FILE_PWD | path join '..' 'scripts' 'nu-lint.nu' | path expand
    let root = mktemp --directory --tmpdir-path $env.TMPDIR 'dots-nu-lint-test.XXXXXX'
    let f = {
        lint: $lint
        root: $root
        repo: ($root | path join repo)
        temp: ($root | path join temp)
        bin: ($root | path join bin)
    }
    try {
        mkdir $f.repo $f.temp $f.bin
        cd $f.repo
        succeeds (^git init --quiet | complete)
        succeeds (invoke $f [check])
        print 'PASS empty repository'

        $'error make {msg: "lint must not execute me"}(char nl)' | save 'has spaces.nu'
        succeeds (invoke $f [check 'has spaces.nu'])
        print 'PASS explicit spaced filename; parser never executes script'

        # Real generators must satisfy source/use resolution without repo startup.
        'use ($nu.cache-dir | path join "mise.nu")
source ($nu.data-dir | path join "zoxide.nu")
error make {msg: "never execute imports"}
' | save imports.nu
        succeeds (invoke $f [format imports.nu])
        succeeds (invoke $f [check imports.nu])
        print 'PASS real mise/zoxide parse-time imports'

        succeeds (^git add 'has spaces.nu' | complete)
        succeeds (^ln -s 'has spaces.nu' linked.nu | complete)
        let linked = invoke $f [check]
        succeeds $linked
        assert ($linked.stdout | str contains 'Checking Nu syntax: linked.nu') 'File symlinks must be discovered'
        let unusual = $"tracked(char nl)name.nu"
        $'print "tracked"(char nl)' | save $unusual
        succeeds (^git add $unusual | complete)
        mkdir nested
        'let   x =  1' | save 'nested/new test.nu'
        'ignored.nu' | save .gitignore
        'def broken [' | save ignored.nu
        fails (invoke $f [check])
        succeeds (invoke $f [format])
        let once = open --raw 'nested/new test.nu'
        succeeds (invoke $f [format])
        assert equal (open --raw 'nested/new test.nu') $once 'Formatting must be idempotent'
        let discovered = invoke $f [check]
        succeeds $discovered
        for file in ['has spaces.nu' $unusual 'nested/new test.nu'] {
            assert ($discovered.stdout | str contains $file) $"Not discovered: ($file)"
        }
        assert not ($discovered.stdout | str contains 'ignored.nu')
        # Tracked files removed from the worktree are skipped.
        rm $unusual
        succeeds (invoke $f [check])
        print 'PASS NUL tracked/untracked discovery; ignored/deleted filtering; format idempotence'

        'def broken [' | save malformed.nu
        fails (invoke $f [check malformed.nu])
        print 'PASS malformed input rejected'
        # Bypass formatter only to prove parser failure is independently nonzero.
        stub $f nufmt 'exit 0'
        with-env {PATH: ($env.PATH | prepend $f.bin)} {
            let parsed = invoke $f [check malformed.nu]
            fails $parsed
            assert ($parsed.stdout | str contains 'Checking Nu syntax: malformed.nu')
        }
        print 'PASS nu-check failure is nonzero even when formatter succeeds'

        for tool in [nufmt mise zoxide] {
            stub $f $tool 'print --stderr "injected failure"; exit 42'
            with-env {PATH: ($env.PATH | prepend $f.bin)} {
                for mode in [check format] {
                    let result = invoke $f [$mode 'has spaces.nu']
                    fails $result
                    assert ($result.stderr | str contains 'injected failure')
                }
            }
            rm ($f.bin | path join $tool)
        }
        print 'PASS formatter and both generator failures; cleanup in both modes'

        # Wrap the real tools: confirm cleared env and sandbox HOME/XDG, and
        # generator cwd outside the checkout. Real tool output is still used.
        for tool in [mise zoxide nufmt] {
            let real = which $tool | first | get path
            let cwd_check = if $tool == nufmt { '' } else {
                'assert ($env.PWD | str starts-with ($env.HOME | path dirname))'
            }
            let probe = 'use std/assert
assert not ("DOTS_LINT_POISON" in $env)
assert not ("MISE_CONFIG_FILE" in $env)
assert equal ($env.HOME | path basename) "home"
for key in [XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME] {
    assert (($env | get $key) | str starts-with ($env.HOME | path dirname))
}
'
            let forward = ' ...$args | complete
    print --no-newline $result.stdout
    print --stderr --no-newline $result.stderr
    exit $result.exit_code
}'
            (stub
                $f
                $tool
                (
                    $probe + $cwd_check + "\ndef --wrapped main [...args: string] {\n    let result = ^" + ($real | to nuon) + $forward
                )
            )
        }
        with-env {
            PATH: ($env.PATH | prepend $f.bin)
            DOTS_LINT_POISON: 'must disappear'
            MISE_CONFIG_FILE: ($f.repo | path join 'must-not-read.toml')
        } {
            succeeds (invoke $f [check imports.nu])
        }
        print 'PASS cleared environment; temporary HOME/XDG; generators outside repo'

        cd $root
        let nonrepo = invoke $f [check]
        fails $nonrepo
        assert ($nonrepo.stderr | str contains 'not a git repository')
        succeeds (invoke $f [
            check
            ($f.repo | path join 'has spaces.nu')
        ])
        print 'PASS discovery failure outside repository; explicit paths still work'
        fails (invoke $f [invalid])
        fails (invoke $f [])
        print 'PASS invalid/missing mode rejected'
        print 'RESULT 10 focused lint groups passed; every invocation checked cleanup'
    } finally {
        cd $original
        rm --recursive --force $root
    }
}
