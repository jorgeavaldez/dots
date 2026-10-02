# Exercise the launcher against real PRoot, without browsers or network access.
use std/assert
use helpers.nu [child ok put contains]

# A fake upstream CLI keeps tests independent of npm and Chromium. Its detached
# child reproduces PRoot's daemon-wait behavior; the normal close command stops it.
def browser-fixture [f: record] {
    let proot = which proot
    assert ($proot | is-not-empty) 'These launcher tests require proot'
    let prefix = $f.root | path join 'native prefix'
    mkdir ($prefix | path join bin)
    ok (^$f.tools.ln -s $proot.0.path ($prefix | path join bin/proot) | complete)
    ok (^$f.tools.ln -s $f.tools.sh ($prefix | path join bin/sh) | complete)
    put ($prefix | path join etc/resolv.conf) "nameserver 192.0.2.53\n"
    let binary = $prefix | path join lib/node_modules/agent-browser/bin/agent-browser-linux-musl-arm64
    put $binary ($"#!($f.tools.sh)\n" + '
case "$1" in
    read) cat /etc/resolv.conf ;;
    stdin) cat ;;
    args) shift; printf "%s\n" "$@" ;;
    fail) printf "output\n"; printf "error\n" >&2; exit 9 ;;
    start)
        sleep 60 </dev/null >/dev/null 2>&1 &
        printf "%s\n" "$!" >"$TEST_DAEMON_PID"
        printf "started\n"
        ;;
    close) kill "$(cat "$TEST_DAEMON_PID")" ;;
    *) exit 2 ;;
esac
')
    ok (^$f.tools.chmod 755 $binary | complete)
    $f | update env ($f.env | merge {
        PREFIX: $prefix
        TEST_DAEMON_PID: ($f.root | path join daemon.pid)
    })
}

export def cases [] {
    [
        {
            name: test_android_agent_browser_launcher_maps_dns_and_preserves_io
            run: {|fixture|
                let f = browser-fixture $fixture
                let launcher = [
                    $f.tools.sh
                    ($f.repo | path join termux/agent-browser-wrapper.sh)
                ]
                let dns = child $f ($launcher | append read) --seconds 5
                ok $dns
                assert equal $dns.stdout "nameserver 192.0.2.53\n"
                let input = "stdin ✓\n\n"
                let echoed = child $f ($launcher | append stdin) --input $input --seconds 5
                ok $echoed
                assert equal $echoed.stdout $input
                let args = child $f ($launcher | append [args 'two words' '--json']) --seconds 5
                ok $args
                assert equal $args.stdout "two words\n--json\n"
                let failure = child $f ($launcher | append fail) --seconds 5
                assert equal $failure.exit_code 9
                assert equal $failure.stdout "output\n"
                assert equal $failure.stderr "error\n"
                assert equal (glob ($f.env.TMPDIR | path join 'agent-browser.*')) []
            }
        }
        {
            name: test_android_agent_browser_launcher_returns_without_killing_daemon
            run: {|fixture|
                let f = browser-fixture $fixture
                let launcher = [
                    $f.tools.sh
                    ($f.repo | path join termux/agent-browser-wrapper.sh)
                ]
                try {
                    let started = child $f ($launcher | append start) --seconds 5
                    ok $started
                    assert equal $started.stdout "started\n"
                    let pid = open --raw $f.env.TEST_DAEMON_PID | str trim
                    ok (child $f [$f.tools.sh -c 'kill -0 "$1"' sh $pid])
                    let dns = child $f ($launcher | append read) --seconds 5
                    ok $dns
                    assert equal $dns.stdout "nameserver 192.0.2.53\n"
                    ok (child $f ($launcher | append close) --seconds 5)
                } finally {
                    if ($f.env.TEST_DAEMON_PID | path exists) {
                        let pid = open --raw $f.env.TEST_DAEMON_PID | str trim
                        child $f [$f.tools.sh -c 'kill "$1" 2>/dev/null || true' sh $pid] | ignore
                    }
                }
                assert equal (glob ($f.env.TMPDIR | path join 'agent-browser.*')) []
            }
        }
        {
            name: test_android_agent_browser_proot_launch_failure_does_not_hang
            run: {|fixture|
                let f = browser-fixture $fixture
                let proot = $f.env.PREFIX | path join bin/proot
                rm $proot
                put $proot ($"#!($f.tools.sh)\n" + 'printf "launch failed\n" >&2; exit 17')
                ok (^$f.tools.chmod 755 $proot | complete)
                let result = child $f [
                    $f.tools.sh
                    ($f.repo | path join termux/agent-browser-wrapper.sh)
                    read
                ] --seconds 5
                assert equal $result.exit_code 17
                contains $result.stderr 'launch failed'
                assert equal (glob ($f.env.TMPDIR | path join 'agent-browser.*')) []
            }
        }
    ]
}
