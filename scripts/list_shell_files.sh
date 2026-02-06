#!/usr/bin/env bash

set -euo pipefail

{
    find . -type f \( -name '.zshrc' -o -name '*.sh' -o -name '*.bash' -o -name '*.zsh' \) ! -path './.git/*'

    if [ -d scripts ]; then
        while IFS= read -r f; do
            head -n 1 "$f" | grep -Eq '^#!.*\b(sh|bash|zsh)\b' && echo "$f"
        done < <(find ./scripts -type f)
    fi
} | sort -u
