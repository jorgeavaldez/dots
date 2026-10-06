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

herdr="${HERDR_BIN_PATH:-herdr}"
agent_data="$("$herdr" agent get "$pane_id" 2>/dev/null | jq -ce '.result.agent // empty')" || agent_data="$event_data"
workspace_id="$(jq -r '.workspace_id // empty' <<<"$agent_data")"
tab_id="$(jq -r '.tab_id // empty' <<<"$agent_data")"
workspace_label=""
tab_label=""
if [[ -n "$workspace_id" ]]; then
    workspace_label="$("$herdr" workspace get "$workspace_id" 2>/dev/null | jq -r '.result.workspace.label // empty')" || workspace_label=""
fi
if [[ -n "$tab_id" ]]; then
    tab_label="$("$herdr" tab get "$tab_id" 2>/dev/null | jq -r '.result.tab.label // empty')" || tab_label=""
fi

agent="$(jq -r '([.name, .display_agent, .agent] | map(select(type == "string" and length > 0)) | first) // "Agent"' <<<"$agent_data")"
content="$(jq -r --arg workspace "$workspace_label" --arg tab "$tab_label" --arg agent "$agent" '
    [$workspace, $tab, (.title | select(. != $agent))]
    | map(select(type == "string" and length > 0))
    | reduce .[] as $part ([]; if index($part) then . else . + [$part] end)
    | join(" · ")
' <<<"$agent_data")"

termux-notification \
    --id "herdr-$pane_id" \
    --group herdr \
    --title "$agent finished" \
    --content "$content" \
    --icon smart_toy \
    --sound
