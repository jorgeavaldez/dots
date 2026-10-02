# Linux and Termux integration tests in Nushell

Run the sequential suite with Nu and its bundled `std/assert` (CI and native
Termux use 0.116.0):

```sh
"$NU_BIN" --no-config-file tests/run.nu
# Optional case-name substring; an empty match is an error:
"$NU_BIN" --no-config-file tests/run.nu --filter concurrent
```

## Tools and environment

Required: Linux or native Termux, Nu, real fnox, age-keygen, zoxide, ncurses `tic`,
GNU coreutils (`env`, `timeout`, `chmod`, `stat`, `readlink`, `ln`, `mkdir`,
`rmdir`), and a POSIX `sh` on PATH. Full bootstrap cases download WezTerm's real terminfo
using Nu's HTTP client, so they require working HTTPS access. Missing required
tools are failures, never skips. Full-suite browser launcher tests require
PRoot; the synthetic SSH socket probe uses Python, and native Android history
restart coverage requires tmux. External Nu test frameworks and formatters are
not required by the runtime suite.

`NU_BIN`, `FNOX_BIN`, `AGE_KEYGEN_BIN`, and `ZOXIDE_BIN` retain their meanings.
If an override is absent, the runner searches PATH. Use actual executable paths,
not mise shims, when the checkout's mise configuration is untrusted. Resolve them
outside the checkout without changing host trust. For example, from a trusted
neutral directory in a POSIX shell:

```sh
export NU_BIN="$(mise exec nu -- which nu)"
export FNOX_BIN="$(mise exec fnox -- which fnox)"
export AGE_KEYGEN_BIN="$(mise exec age -- which age-keygen)"
export ZOXIDE_BIN="$(mise exec zoxide -- which zoxide)"
# Select an existing scratch directory appropriate to your machine:
export TMPDIR=/absolute/path/to/scratch
cd /path/to/dots
"$NU_BIN" --no-config-file tests/run.nu
```

Each case gets a private directory under TMPDIR. Every integration child uses an
absolute executable, `env -i`, an explicit environment allowlist, a fixture
working directory, and isolated HOME, all four XDG directories, and TMPDIR.
This is deliberately not just `with-env`: the fresh Nu process must see the
isolated paths before initialization. Host fnox/mise variables, display values,
and credentials are not inherited. SSH preservation tests create only synthetic
files; clipboard tests use Nu stubs, never the desktop or phone clipboard.
Every fixture installs failing sentinels for Termux, Wayland, and X11 clipboard
commands. A clipboard case must replace them with fixture-only implementations
before it can use those commands. This blocks host APIs even when tool paths
also expose host utilities.

## Coverage and boundaries

The suite covers:

- Bootstrap: Linux integrations/terminfo, managed symlinks, backups, conflicts,
  overrides, and Android overlay selection/native roots.
- Secrets: real age/fnox encryption and decryption, local encrypted source input,
  refresh/rotation/removal, private modes, failed enrollment/refresh preservation,
  identity import, native hook loading, and concurrent enrollment.
- Browser launcher: real PRoot resolver mapping, stream/exit-code preservation,
  detached daemon lifetime, and launch-failure cleanup.
- Shell: interactive startup, synthetic SSH agents, stubbed clipboard round
  trips, native Android history restart, denied host clipboard access, and
  forced timeout/process-group cleanup.

The runner probes the resolved `NU_BIN` runtime's OS before selecting cases.
Linux-specific bootstrap and shell cases declare `platform: linux`. Native
Android reports them as `SKIP`, with the reason, rather than trying to simulate
Linux by clearing `TERMUX_VERSION`/`PREFIX`. Clearing environment variables does
not change `$nu.os-info.name`; changing production platform detection to fool
tests would test the wrong behavior. Android-overlay cases also run on Linux,
while the actual native-history restart only runs with native Android Nu.

Two additional sentinel cases cover absent native hooks and installed hooks
without a cache: no dynamic mise lookup, enrollment, or 1Password fallback.
An installed native hook does invoke its embedded real fnox binary; “no-op”
means no secrets loaded, no cache/identity created, and no fallback tool calls,
not zero external processes.

With the current 49 cases, Linux runs all 49; native Android runs 37 and reports
12 Linux-only cases skipped. Skips are counted separately from passes. Linux CI
continues to exercise the Linux-only assertions; an Android pass is not evidence
for those paths. Subcases stay within their original cases.
The mise bulk `install --yes` boundary is mocked, with strict argument checking;
fnox, age, zoxide, symlinks, permissions, `tic`, and terminfo download remain real.
All executable stubs, including clipboard and paused age-keygen, use Nu. The
clipboard stub reads `/dev/stdin` directly because script `main` does not receive
stdin as `$in` unless Nu is launched with `--stdin`.

## Nu lint tooling probe

Run the separate Nu-only probe with `nu`, `mise`, `zoxide`, `nufmt`, Git, `env`,
and `chmod`/`ln` available, and an existing `TMPDIR`:

```nu
nu --no-config-file tests/nu-lint.nu
```

It checks the real `scripts/nu-lint.nu` entry point: empty/non-repositories,
explicit spaced filenames, NUL-separated tracked/untracked discovery (including
newlines in filenames), ignored/deleted files, format/check and idempotence,
malformed input, independent parser failure, and failing formatter/generators.
Real mise/zoxide imports are generated outside the checkout. Nu wrappers verify
cleared environment and isolated HOME/XDG; fault injection does not replace the
real-tool success cases. Every invocation asserts sandbox cleanup. Checked
scripts are deliberately runtime errors to prove lint does not execute them.
The expected result is 10 passing probe groups, separate from the runtime
integration cases. This probe is not implicitly run by `make lint`.

## Failure handling

The runner reports every case, removes each fixture in `finally`, and exits 1
if any case failed. `complete` results are asserted explicitly; expected secrets
failures cannot pass merely because a child timed out. Ordinary children have a
90-second GNU timeout and a 2-second forced-kill grace period. Interactive-shell
checks use 10 seconds; native history's terminal/restart scenario uses 20 seconds.
The timeout regression deliberately ignores TERM and verifies forced termination
within the grace period, with no running descendant left behind. Native Nu's
negative signal statuses are normalized to shell exit codes in the shared child
boundary, so SIGKILL is 137 and cannot masquerade as an expected command error.

For a potentially hanging run, use an auditable tmux session and an outer
`timeout --kill-after=5s 120s` around the suite. The outer bound is not a substitute
for per-child cleanup. Interrupting the runner can bypass Nu's `finally`; child
deadlines still bound their lifetime, but immediate interrupt cleanup is not
guaranteed. Do not remove a fixture while its children are still running.

The enrollment race uses entered/release files rather than sleep-based ordering.
Its wrapper has a 15-second barrier deadline; the first child has a 20-second
process-group timeout. The parent waits at most 10 seconds for entry, always
releases the barrier in `finally`, collects the result with a bounded mailbox
wait, asserts the child's exit status, and checks that the job terminated before
fixture deletion. Nu jobs are experimental; keep these cleanup checks when
changing the race.

Migration validation included disposable copies that deliberately failed an
assertion after the entered barrier and failed the background winner. Both
returned exit 1 with `0 passed; 1 failed`, cleaned fixtures, and left no test
children. Separate probes verified missing-tool failure, environment isolation,
and timeout exit 124 with child cleanup. The old baseline passed 27/27 before
the Python files were removed; the migrated suite passed 29/29.

For formatting, use the repository's pinned nufmt version. A migration-time
nufmt quirk incorrectly copied defaults onto preceding space-separated signature
parameters and added invalid `: bool` annotations to defaulted switches. These
files use comma/newline-separated parameters and ordinary `--fail` switches;
both nufmt's repeat dry-run and Nu parser checks must pass.

The Linux workflow runs this suite in Arch and Debian containers, followed by
repository-wide formatting and parser checks. It is not a desktop smoke test.
