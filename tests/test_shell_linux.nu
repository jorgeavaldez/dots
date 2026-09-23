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
