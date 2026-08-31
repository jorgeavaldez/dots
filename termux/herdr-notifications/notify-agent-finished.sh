#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${TERMUX_VERSION:-}" || "${PREFIX:-}" != */com.termux/files/usr ]]; then
    exit 0
fi

event_json="${HERDR_PLUGIN_EVENT_JSON:-}"
if [[ -z "$event_json" ]]; then
    exit 0
fi

event_data="$(jq -ce '(.data // .) | select(type == "object")' <<<"$event_json")" || exit 0
if [[ "$(jq -r '.agent_status // empty' <<<"$event_data")" != "done" ]]; then
    exit 0
fi

pane_id="$(jq -r '.pane_id // empty' <<<"$event_data")"
if [[ -z "$pane_id" ]]; then
    exit 0
fi

agent="$(jq -r '([.display_agent, .agent] | map(select(type == "string" and length > 0)) | first) // "Agent"' <<<"$event_data")"
content="$(jq -r '[.title, .workspace_id, .pane_id] | map(select(type == "string" and length > 0)) | join(" · ")' <<<"$event_data")"

termux-notification \
    --id "herdr-$pane_id" \
    --group herdr \
    --title "$agent finished" \
    --content "$content" \
    --icon smart_toy \
    --sound
