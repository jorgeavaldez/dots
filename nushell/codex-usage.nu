use std-rfc/kv *

const usage_endpoint = "https://chatgpt.com/backend-api/codex/usage"
const codex_auth_file = "~" | path expand | path join ".codex" "auth.json"

def codex-auth-tokens []: nothing -> record<id_token: string, access_token: string, refresh_token: string, account_id: string> {
    if not ($codex_auth_file | path exists) {
        error make -u {
            msg: $"($codex_auth_file) does not exist"
            help: "log in using codex cli manually first"
        }
    }

    $codex_auth_file | open --raw | from json | get tokens
}

def make-request [endpoint: string]: nothing -> any {
    let tokens = codex-auth-tokens
    let headers = {
        Authorization: $'Bearer ($tokens.access_token)'
        ChatGPT-Account-Id: $tokens.account_id
        Accept: 'application/json'
    }
    http get -H $headers $endpoint
}

def codex-usage-req []: nothing -> record {
    let cached = kv get -u codex-usage

    if $cached != null and ((date now) < ($cached.fetched_at + 5min)) {
        return $cached.response
    }

    let response = make-request $usage_endpoint

    {
        fetched_at: (date now)
        response: $response
    } | kv set -u codex-usage | ignore

    $response
}

export def main [] {
    let rate_limit_window = codex-usage-req
    | get rate_limit.primary_window

    let reset_at = $rate_limit_window.reset_at | into datetime -f '%s'

    {
        used_percent: $rate_limit_window.used_percent
        limit_window: ($rate_limit_window.limit_window_seconds | into duration --unit sec)
        reset_after: ($rate_limit_window.reset_after_seconds | into duration --unit sec)
        reset_on: ($reset_at | date humanize)
        reset_date: ($reset_at | format date "%Y-%m-%d %H:%M:%S")
    }
}
