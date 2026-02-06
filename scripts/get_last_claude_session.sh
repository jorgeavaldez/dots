#!/bin/bash

# Get the most recent session file from munty project
MUNTY_DIR="$HOME/.claude/projects/-Users-jorge-proj-munty"
LATEST_SESSION=$(ls -t "$MUNTY_DIR"/*.jsonl 2>/dev/null | head -n 1)

if [[ -z "$LATEST_SESSION" ]]; then
    echo "No session files found in $MUNTY_DIR"
    exit 1
fi

echo "Latest session: $(basename "$LATEST_SESSION")"
echo "---"

# Extract the last assistant message content
LAST_CONTENT=$(tail -n 20 "$LATEST_SESSION" | grep '"role":"assistant"' | tail -n 1 | jq -r '.message.content[0].text // empty')

if [[ -z "$LAST_CONTENT" ]]; then
    echo "No assistant message found in latest session"
    exit 1
fi

# Display with glow if available, otherwise bat, otherwise cat
if command -v glow >/dev/null 2>&1; then
    echo "$LAST_CONTENT" | glow -
elif command -v bat >/dev/null 2>&1; then
    echo "$LAST_CONTENT" | bat --language=markdown --style=plain
else
    echo "$LAST_CONTENT"
fi

# Copy to clipboard (works on macOS)
echo "$LAST_CONTENT" | pbcopy
echo ""
echo "Content copied to clipboard!"
