# Real interactive Nu startup; integration and clipboard commands use Nu stubs.
use std/assert
use helpers.nu [
    child
    ok
    script
    put
    absent
    contains
]

# Each case receives a fresh, clean-environment fixture from the shared runner.
def shell-fixture [f: record] {
    script $f mise 'def main [...args: string] { print "export-env {}" }'
    put ($f.home | path join ".local/share/nushell/zoxide.nu") ""
    $f | update env ($f.env | merge {SSH_AUTH_SOCK: "/device/agent.sock",  TERM: "xterm"})
}

def interactive [f: record, code: string, --fail] {
    let result = child $f [
        $f.tools.nu
        --env-config
        ($f.repo | path join "nushell/env.nu")
        --config
        ($f.repo | path join "nushell/config.nu")
        -i
        -c
        $code
    ]
    if not $fail { ok $result }
    $result
}

def clipboard-commands [f: record] {

    # Save the incoming byte stream directly; never collect/trim or print it.
    script $f wl-copy 'def main [] { open --raw /dev/stdin | save --raw --force ($env.HOME | path join "clipboard") }'
    script $f wl-paste 'def --wrapped main [...args: string] { print --no-newline (open --raw ($env.HOME | path join "clipboard")) }'
    script $f xclip 'def --wrapped main [...args: string] {
        if "-in" in $args {
            open --raw /dev/stdin | save --raw --force ($env.HOME | path join "clipboard")
        } else {
            print --no-newline (open --raw ($env.HOME | path join "clipboard"))
        }
    }'
}

export def cases [] {
    [
        {
            name: "test_android_shell_overlay_locale_clipboard_and_jj_dispatch"
            run: {|fixture|
                let base = shell-fixture $fixture
                let f = $base | update env (
                    $base.env
                    | merge {TERMUX_VERSION: 'test' PREFIX: ($base.root | path join native) LANG: 'custom.UTF-8'}
                )
                script $f mise 'def main [...args: string] {
                    if $args != ["activate" "nu"] or $env.MISE_AUTO_ENV != "1" { error make {msg: "Unexpected startup lookup or missing Android overlay"} }
                    print "export-env {}"
                }'
                script $f termux-clipboard-set 'def main [] { open --raw /dev/stdin | save --raw --force ($env.HOME | path join "clipboard") }'
                script $f termux-clipboard-get 'def main [] { print --no-newline (open --raw ($env.HOME | path join "clipboard")) }'
                script $f jj 'def --wrapped main [...args: string] { if $args == ["--stdin"] { print --no-newline (open --raw /dev/stdin) } else { print ($args | to json -r) } }'
                let text = "android ✓\n\n"
                let state = (
                    interactive $f (
                        ($text | to json -r) + ' | pbcopy; {clipboard: (pbpaste), sock: $env.SSH_AUTH_SOCK, lang: $env.LANG, ctype: $env.LC_CTYPE, jj: (j --version | from json), pager: $env.PAGER, shell: $env.SHELL, exe: $nu.current-exe} | to json -r'
                    )
                ).stdout | from json
                assert equal $state.clipboard $text
                assert equal $state.sock $f.env.SSH_AUTH_SOCK
                assert equal $state.lang 'custom.UTF-8'
                assert equal $state.ctype 'en_US.UTF-8'
                assert equal $state.jj ['--version']
                assert equal $state.pager 'less -FRX'
                assert equal (
                    (
                        interactive $f '("synthetic stdin\n" | jj --stdin | complete).stdout | to json -r'
                    ).stdout
                    | from json
                ) "synthetic stdin\n"
                assert equal $state.shell $state.exe
            }
        }
        {
            name: "test_android_history_configuration_and_native_restart"
            run: {|fixture|
                let base = shell-fixture $fixture
                let f = $base | update env (
                    $base.env | merge {TERMUX_VERSION: 'test' PREFIX: ($base.root | path join native)}
                )
                let old_history = $f.config | path join nushell/history.txt
                put $old_history "synthetic-old-history\n"
                let state = (
                    interactive $f '{os: $nu.os-info.name, format: $env.config.history.file_format} | to json -r'
                ).stdout | from json
                assert equal $state.format sqlite
                assert equal (open --raw $old_history) "synthetic-old-history\n"
                # Configuration is covered everywhere; the native lock regression
                # needs Android and a real terminal, not Linux's working locks.
                if $state.os != 'android' { return }
                let tmux = which tmux
                assert ($tmux | is-not-empty) 'This native Termux history fixture requires tmux'
                ok (
                    child $f [
                        $f.tools.sh -c r#'
set -eu
nu=$1; env_config=$2; config=$3; tmux=$4; shell=$5
socket="$HOME/history.sock"
trap '"$tmux" -S "$socket" kill-server 2>/dev/null || true' EXIT
trap 'exit 1' HUP INT TERM
# Each shell has a real terminal and exits before the next one starts.
# Keep its wrapper alive so the private server can deliver the exit signal.
wrapper='"$1" --env-config "$2" --config "$3" -i -e "^$4 -S $5 wait-for -S ready"; status=$?; printf "%s\n" "$status" > "$HOME/exit-status"; "$4" -S "$5" wait-for -S stopped; read -r hold'
"$tmux" -S "$socket" -f /dev/null new-session -d -s history "$shell" -c "$wrapper" -- "$nu" "$env_config" "$config" "$tmux" "$socket"
"$tmux" -S "$socket" wait-for ready
# Submit one line per shell: Reedline can discard a separately queued exit
# while starting its next read. Keep real terminal input and restart coverage.
"$tmux" -S "$socket" send-keys -t history:0.0 -l 'print "synthetic-termux-history"; exit'
"$tmux" -S "$socket" send-keys -t history:0.0 Enter
"$tmux" -S "$socket" wait-for stopped
read -r status < "$HOME/exit-status"
test "$status" = 0
"$tmux" -S "$socket" capture-pane -p -t history:0.0 > "$HOME/first-terminal"
"$tmux" -S "$socket" new-window -d -t history -n restarted "$shell" -c "$wrapper" -- "$nu" "$env_config" "$config" "$tmux" "$socket"
"$tmux" -S "$socket" wait-for ready
"$tmux" -S "$socket" send-keys -t history:restarted.0 -l 'history | where command == "print \"synthetic-termux-history\"; exit" | length | save ($env.HOME | path join persisted-count); exit'
"$tmux" -S "$socket" send-keys -t history:restarted.0 Enter
"$tmux" -S "$socket" wait-for stopped
read -r status < "$HOME/exit-status"
test "$status" = 0
"$tmux" -S "$socket" capture-pane -p -t history:restarted.0 > "$HOME/second-terminal"
'#                      --
                        $f.tools.nu
                        ($f.repo | path join nushell/env.nu)
                        ($f.repo | path join nushell/config.nu)
                        $tmux.0.path
                        $f.tools.sh
                    ]
                )
                assert equal (open --raw ($f.home | path join persisted-count) | str trim) '1'
                assert ($f.config | path join nushell/history.sqlite3 | path exists)
                assert equal (open --raw $old_history) "synthetic-old-history\n"
                for name in [first-terminal second-terminal] {
                    let terminal = open --raw ($f.home | path join $name)
                    assert not ($terminal | str contains 'continuing without history') $terminal
                    assert not ($terminal | str contains 'Error:') $terminal
                }
            }
        }
        {
            name: "test_android_reuses_service_socket_without_enrollment"
            run: {|fixture|
                let base = shell-fixture $fixture
                let prefix = $base.root | path join native
                # Bind and close a synthetic socket; no agent or keys are used.
                let python = which python3
                assert ($python | is-not-empty) 'This socket fixture requires python3'
                let socket = $prefix | path join var/run/ssh-agent.socket
                mkdir ($socket | path dirname)
                ok (
                    child $base [
                        $python.0.path
                        '-c'
                        'import socket, sys; s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()'
                        $socket
                    ]
                )
                let f = $base | update env (
                    $base.env
                    | reject SSH_AUTH_SOCK
                    | merge {PREFIX: $prefix TERMUX_VERSION: 'test'}
                )
                let state = (
                    interactive $f '{sock: $env.SSH_AUTH_SOCK, lang: $env.LANG} | to json -r'
                ).stdout | from json
                assert equal $state.sock ($prefix | path join var/run/ssh-agent.socket)
                assert equal $state.lang 'en_US.UTF-8'
                absent ($f.config | path join fnox)
            }
        }
        {
            name: "test_linux_jj_dispatch_preserves_stdin_and_bump_errors"
            run: {|fixture|
                let f = shell-fixture $fixture
                script $f jj 'def --wrapped main [...args: string] {
                    if $args == ["--stdin"] { print --no-newline (open --raw /dev/stdin) } else if $args == ["currbm-name"] { print --stderr "synthetic failure"; exit 73 } else { print ($args | to json -r) }
                }'
                assert equal (
                    (interactive $f 'j --version | from json | to json -r').stdout
                    | from json
                ) ['--version']
                assert equal (
                    (
                        interactive $f '("synthetic stdin\n" | jj --stdin | complete).stdout | to json -r'
                    ).stdout
                    | from json
                ) "synthetic stdin\n"
                let result = interactive $f 'bump' --fail
                assert ($result.exit_code != 0)
                contains $result.stderr 'synthetic failure'
            }
        }
        {
            name: "test_linux_shell_and_device_agent"
            run: {|fixture|
                let f = shell-fixture $fixture
                let result = (
                    interactive $f '{shell: $env.SHELL, exe: $nu.current-exe, sock: $env.SSH_AUTH_SOCK, path: $env.PATH} | to json -r'
                ).stdout | from json
                assert equal $result.shell $result.exe
                assert equal $result.sock $f.env.SSH_AUTH_SOCK
                assert ($f.bin in $result.path)
            }
        }
        {
            name: "test_wayland_clipboard_preserves_bytes"
            run: {|fixture|
                let base = shell-fixture $fixture
                let f = $base | update env ($base.env | merge {WAYLAND_DISPLAY: "wayland-0"})
                clipboard-commands $f
                let text = "linux ✓\n\n"
                let code = $"($text | to json -r) | pbcopy; pbpaste | to json -r"
                assert equal ((interactive $f $code).stdout | from json) $text
                assert equal (open --raw ($f.home | path join "clipboard")) $text
            }
        }
        {
            name: "test_x11_clipboard_preserves_bytes"
            run: {|fixture|
                let base = shell-fixture $fixture
                let f = $base | update env ($base.env | merge {DISPLAY: ":0"})
                clipboard-commands $f
                let text = "x11 ✓\n"
                let code = $"($text | to json -r) | pbcopy; pbpaste | to json -r"
                assert equal ((interactive $f $code).stdout | from json) $text
                assert equal (open --raw ($f.home | path join "clipboard")) $text
            }
        }
        {
            name: "test_headless_clipboard_reports_missing_session"
            run: {|fixture|
                let f = shell-fixture $fixture
                let result = interactive $f '"test" | pbcopy' --fail
                assert ($result.exit_code != 0)
                contains ($result.stderr | str lowercase) "display"
            }
        }
        {
            name: "test_absent_native_hook_does_not_resolve_tools"
            run: {|fixture|
                let f = shell-fixture $fixture
                # Mise activation is intentional. Any lookup/fallback is not.
                script $f mise 'def --wrapped main [...args: string] {
                if $args == ["activate" "nu"] {
                    print "export-env {}"
                } else {
                    $args | to json -r | save --force ($env.HOME | path join "unexpected-mise")
                    exit 73
                }
            }'
                for name in [fnox op age-keygen zoxide] {
                    script $f $name 'def --wrapped main [...args: string] {
                    "called" | save --force ($env.HOME | path join "unexpected-tool")
                    exit 73
                }'
                }
                let hook = $f.home | path join ".local/share/nushell/vendor/autoload/fnox.nu"
                let cache = $f.config | path join "fnox/config.toml"
                absent $hook
                absent $cache
                # -c does not display a prompt; exercise installed pre-prompt hooks
                # explicitly as well, so deferred lookup fallbacks cannot escape.
                let result = interactive $f 'for hook in ($env.config.hooks.pre_prompt? | default []) { do --env $hook }; {shell: $env.SHELL, exe: $nu.current-exe} | to json -r'
                let state = $result.stdout | from json
                assert equal $state.shell $state.exe
                absent ($f.home | path join "unexpected-mise")
                absent ($f.home | path join "unexpected-tool")
                absent $hook
                absent $cache
            }
        }
    ]
}
