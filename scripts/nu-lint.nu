#!/usr/bin/env nu

# External failures must not become an empty file list or a successful lint.
def checked [result: record] {
    if $result.exit_code != 0 {
        error make {msg: $"Command failed [($result.exit_code)]: ($result.stderr)($result.stdout)"}
    }
    $result.stdout
}

def main [mode: string, ...files: string] {
    if $mode not-in [format check] {
        print --stderr 'Usage: nu-lint.nu format|check [files...]'
        exit 2
    }
    let targets = if ($files | is-empty) {
        # NUL separation preserves spaces and newlines, including untracked tests.
        checked (
            ^git ls-files --cached --others --exclude-standard -z -- '*.nu'
            | complete
        )
        | split row (char nul)
        | where {|file| $file != '' and ($file | path expand | path type) == file }
    } else {
        $files
    }
    if ($targets | is-empty) { return }

    let sandbox = mktemp --directory --tmpdir 'dots-nu-lint.XXXXXX'
    try {
        let home = $sandbox | path join home
        let config = $sandbox | path join config
        let cache = $sandbox | path join cache
        let data = $sandbox | path join data
        mkdir $home $config $cache $data
        # MSYS env.exe converts POSIX PATH for native Windows programs. Preserve
        # PATHEXT so Nu can find extensionless commands such as `mise`.
        let path = if $nu.os-info.name == 'windows' {
            ^cygpath -u -p ($env.PATH | str join (char esep)) | str trim
        } else {
            $env.PATH | str join (char esep)
        }
        let isolated = [
            '-i'
            $"PATH=($path)"
            $"HOME=($home)"
            $"XDG_CONFIG_HOME=($config)"
            $"XDG_CACHE_HOME=($cache)"
            $"XDG_DATA_HOME=($data)"
        ]
        let isolated = if $nu.os-info.name == 'windows' {
            $isolated | append $"PATHEXT=($env.PATHEXT)"
        } else { $isolated }
        # Generate real parse-time imports outside the checkout, never startup,
        # bootstrap, fnox hooks, or secrets. Each generator status is checked.
        do {
            cd $sandbox
            checked (^env ...$isolated $nu.current-exe --no-config-file -c '
                mkdir $nu.cache-dir $nu.data-dir
                let mise = ^mise activate nu | complete
                if $mise.exit_code != 0 { print --stderr $mise.stderr; exit $mise.exit_code }
                $mise.stdout | save --force ($nu.cache-dir | path join "mise.nu")
                let zoxide = ^zoxide init nushell | complete
                if $zoxide.exit_code != 0 { print --stderr $zoxide.stderr; exit $zoxide.exit_code }
                $zoxide.stdout | save --force ($nu.data-dir | path join "zoxide.nu")
            ' | complete) | ignore
        }
        let flags = if $mode == check { ['--dry-run'] } else { [] }
        checked (^env ...$isolated nufmt ...$flags ...$targets | complete) | print --no-newline
        if $mode == check {
            for file in $targets {
                print $"Checking Nu syntax: ($file)"
                # nu-check is parser-only and returns bool: false must fail.
                checked (^env ...$isolated $"NU_CHECK_FILE=($file)" $nu.current-exe --no-config-file -c '
                    if not (nu-check --debug $env.NU_CHECK_FILE) { exit 1 }
                ' | complete) | ignore
            }
        }
    } finally {
        rm --recursive --force $sandbox
    }
}
