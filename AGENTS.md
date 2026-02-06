# AGENTS.md

Guidelines for coding agents working in this repository.

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
