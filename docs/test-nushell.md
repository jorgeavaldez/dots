# Linux integration tests in Nushell

Run the sequential suite with Nu 0.115.1 and its bundled `std/assert`:

```sh
"$NU_BIN" --no-config-file tests/run.nu
# Optional case-name substring; an empty match is an error:
"$NU_BIN" --no-config-file tests/run.nu --filter concurrent
```

## Tools and environment

Required: Linux, Nu 0.115.1, real fnox, age-keygen, zoxide, ncurses `tic`,
GNU coreutils (`env`, `timeout`, `chmod`, `stat`, `readlink`, `ln`, `mkdir`,
`rmdir`), and `/bin/sh`. Full bootstrap cases download WezTerm's real terminfo
using Nu's HTTP client, so they require working HTTPS access. Missing required
tools are failures, never skips. Python and external Nu test frameworks are not
required. The runtime suite does not require a formatter.

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
files; clipboard tests use Nu stubs, never the desktop clipboard.

## Coverage and boundaries

The original 27 Python cases retain their names and behavioral assertions:

- 8 bootstrap cases: dry run, real integrations/terminfo, managed symlinks,
  backups, rerun idempotence, mutable local state, dangling links, conflicts,
  overrides, and both Termux rejection markers.
- 15 secrets cases: real age/fnox encryption and decryption, private modes,
  injected chmod failures, staging cleanup, identity/config preservation,
  import validation, failed 1Password refresh, native hook cache loading,
  and deterministic concurrent enrollment.
- 4 shell cases: interactive startup, synthetic SSH agent preservation,
  Wayland/X11 Unicode clipboard round trips with exact trailing newlines,
  and the headless error.

Two additional sentinel cases cover absent native hooks and installed hooks
without a cache: no dynamic mise lookup, enrollment, or 1Password fallback.
An installed native hook does invoke its embedded real fnox binary; “no-op”
means no secrets loaded, no cache/identity created, and no fallback tool calls,
not zero external processes.

Expected total: 29 passed, 0 failed. Subcases stay within their original cases.
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
The expected result is 10 passing probe groups, separately from the 29 runtime
integration cases. This probe is not implicitly run by `make lint`.

## Failure handling

The runner reports every case, removes each fixture in `finally`, and exits 1
if any case failed. `complete` results are asserted explicitly; expected secrets
failures cannot pass merely because a child timed out. Ordinary children have a
90-second GNU timeout and a 2-second forced-kill grace period.

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
