# AGENTS.md

Guidelines for coding agents working in this repository.

## Cross-platform requirement

This repository is shared across Linux, macOS, and Android/Termux. Shared dotfiles must remain portable across all three platforms.

- Do not commit device-specific absolute paths, credential helpers, `safe.directory` exceptions, or other machine-local state to shared configuration files such as `git/config`.
- Keep Android-only setup in `install.android.sh`, `termux/`, or an explicit platform conditional when shared configuration genuinely needs different behavior.
- Keep per-device configuration outside the repository.
- Remember that `~/.gitconfig` may be symlinked to the tracked `git/config`; commands such as `git config --global` and `gh auth setup-git` can therefore create unintended tracked changes. Review and remove machine-specific output from such tools.

## Shell startup performance

- Never resolve tool paths with `mise which`, `mise where`, or equivalent mise lookups in shell startup files, autoload scripts, or prompt hooks. `mise which fnox` previously added about 0.8 seconds to every Nu startup on Windows.
- Resolve paths and generate static integrations during bootstrap or explicit setup commands instead. For fnox, `secrets setup-shell` owns generation; Nu only loads the generated native hook at startup. Rerun setup after tool upgrades.
- Do not add a startup lookup fallback for missing or stale generated files. Document the explicit repair command instead.
- Native mise activation and its environment hook are separate from these extra tool-path lookups; retain them unless their behavior is explicitly in scope.

## Shell formatting

If you edit any shell file, run formatting before finishing:

```bash
make format
```

Then verify formatting is clean:

```bash
make lint
```

Shell files are discovered automatically by `scripts/list_shell_files.sh` and include:
- `.zshrc`
- `*.sh`, `*.bash`, `*.zsh`
- extensionless shell scripts in `scripts/` (detected by shebang)

Do not manually maintain a file list for formatting; use the Makefile targets.

Nushell files (`*.nu`, including `tests/`) are discovered from tracked and
non-ignored untracked files by `scripts/nu-lint.sh`. `make format` runs `nufmt`
in place; `make lint` runs `nufmt --dry-run` and Nu's native `nu-check --debug`.
The latter is parser/syntax checking, not a separate style or semantic linter.
Have `shfmt`, `nufmt`, `nu`, `mise`, and `zoxide` on PATH before running these
commands. CI pins nufmt's source commit in `.github/workflows/linux.yml`; use
that revision when reproducing CI formatting (there are no upstream releases).

Nu resolves `use`/`source` during parsing, even inside runtime conditionals.
The check generates real mise/zoxide integrations under temporary HOME/XDG
paths with a cleared environment, without running the repository's startup
files, bootstrap, fnox hooks, or secret resolution. Do not replace this with
executing each `.nu` file or reading the developer's generated startup files.
Parser checks do not prove runtime behavior or validate other operating systems;
keep isolated integration tests for that coverage.
