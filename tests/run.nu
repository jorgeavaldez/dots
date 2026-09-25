#!/usr/bin/env nu
# Sequential runner: fail visibly, clean every fixture, return nonzero on failure.
use std/assert
use helpers.nu [tools fixture]
use test_bootstrap.nu
use test_linux_secrets.nu
use test_shell_linux.nu

# Optional substring selects cases without hiding a misspelled/empty selection.
def main [--filter: string = ''] {
    let resolved = tools
    let cases = (test_bootstrap cases) | append (test_linux_secrets cases) | append (test_shell_linux cases) | where {|case| $case.name | str contains $filter }
    assert ($cases | is-not-empty) $"No tests matched: ($filter)"
    mut passed = 0
    mut failed = 0
    for case in $cases {
        let f = fixture $resolved
        let failure = try {
            do $case.run $f | ignore
            null
        } catch {|err| $err } finally {
            rm --recursive --force $f.root
        }
        if $failure == null {
            $passed += 1
            print $"PASS ($case.name)"
        } else {
            $failed += 1
            print --stderr $"FAIL ($case.name): ($failure.msg)"
        }
    }
    assert equal (job list | length) 0 'Leaked background jobs'
    print $"RESULT ($passed) passed; ($failed) failed; ($cases | length) total"
    if $failed != 0 { exit 1 }
}
