# Shared interactive config for Windows, macOS, and Linux.
$env.config.show_banner = false
$env.config.edit_mode = "vi"

# Native Carapace completions only: no Bash/Zsh/Fish completion bridges.
# Keep all words when expanding aliases (for example dco -> docker compose).
$env.config.completions.external.enable = true
$env.config.completions.external.completer = {|spans|
    let expansion = scope aliases | where name == $spans.0 | get -o 0.expansion
    let words = if $expansion == null { [$spans.0] } else {
        $expansion | split row " "
    }
    let spans = ($words | append ($spans | skip 1) | update 0 {|word|
        $word | str replace --regex '^\^' '' | str replace --regex '\.exe$' ''
    })
    try {
        with-env {CARAPACE_BRIDGES: ""} {
            let result = (^carapace $spans.0 nushell ...$spans | from json)
            if ($result | is-empty) { null } else { $result }
        }
    } catch { null }
}

alias j = ^jj
alias js = ^jj st
alias jd = ^jj diff
alias psh = ^jj git push
alias n = ^nvim
alias e = ^nvim
alias c = clear
alias l = ls --all --long
alias h = herdr
alias dco = ^docker compose
# Replace Nu to reload startup files; temporary variables/definitions are lost.
alias reload = exec nu

const links_module = path self | path expand | path dirname | path join "links.nu"
use $links_module symlink

const secrets_module = path self | path expand | path dirname | path join "secrets.nu"
use $secrets_module

const codex_usage_module = path self | path expand | path dirname | path join "codex-usage.nu"
use $codex_usage_module

# Remove only links, never their targets or ordinary files/directories.
def rmsymlink [link: path] {
    let link = $link | path expand --no-symlink
    if ($link | path type) != "symlink" {
        error make {msg: $"Not a symlink or junction: ($link)"}
    }
    rm $link
}

def --env proj [] {
    cd ("~" | path expand | path join "proj")
}

# Without an argument or pipeline, jj opens the configured editor.
def commit [message?: string] {
    let piped = $in
    if $message != null {
        ^jj commit --message $message
    } else if $piped != null {
        ^jj commit --message ($piped | into string)
    } else {
        ^jj commit
    }
}

def bump [] {
    let result = (^jj currbm-name | complete)
    if $result.exit_code != 0 {
        error make {
            msg: ($result.stderr | str trim)
        }
    }
    let bookmarks = $result.stdout | lines | where {|name| $name != ""}
    if ($bookmarks | length) != 1 {
        error make {msg: "bump requires exactly one current bookmark."}
    }
    ^jj bookmark move $bookmarks.0 --to @-
}

# Use OS clipboard APIs, not clip.exe's legacy code-page conversion.
def pbcopy []: string -> nothing {
    let text = $in
    match $nu.os-info.name {
        "macos" => {
            $text | ^/usr/bin/pbcopy
        }
        "windows" => {
            $text | ^powershell.exe -NoProfile -NonInteractive -Command '
                [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
                $text = [Console]::In.ReadToEnd()
                if ($text.Length -eq 0) {
                    Add-Type -AssemblyName System.Windows.Forms
                    [System.Windows.Forms.Clipboard]::Clear()
                } else {
                    Set-Clipboard -Value $text
                }
            '
        }
        "linux" => {
            if ($env.WAYLAND_DISPLAY? | default "") != "" {
                $text | ^wl-copy
            } else if ($env.DISPLAY? | default "") != "" {
                $text | ^xclip -selection clipboard -in
            } else {
                error make {msg: "Clipboard requires a Wayland or X11 display; this session is headless."}
            }
        }
        _ => { error make {msg: "Clipboard integration is not configured for this platform."} }
    }
}

def pbpaste []: nothing -> string {

    # Capture stdout explicitly: Nu trims a trailing newline when collecting
    # an external byte stream into a variable or subexpression.
    let result = match $nu.os-info.name {
        "macos" => {
            ^/usr/bin/pbpaste | complete
        }
        "windows" => {
            ^powershell.exe -NoProfile -NonInteractive -Command '
                [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
                [Console]::Out.Write((Get-Clipboard -Raw))
            ' | complete
        }
        "linux" => {
            if ($env.WAYLAND_DISPLAY? | default "") != "" {
                ^wl-paste --no-newline | complete
            } else if ($env.DISPLAY? | default "") != "" {
                ^xclip -selection clipboard -out | complete
            } else {
                error make {msg: "Clipboard requires a Wayland or X11 display; this session is headless."}
            }
        }
        _ => { error make {msg: "Clipboard integration is not configured for this platform."} }
    }
    if $result.exit_code != 0 {
        error make {
            msg: ($result.stderr | str trim)
        }
    }
    $result.stdout
}

def repo-url [repo_name?: string]: nothing -> string {
    $repo_name
    | default {
        pwd | path basename
    }
    | gh repo view $in --json sshUrl
    | from json
    | get sshUrl
}

use ($nu.cache-dir | path join "mise.nu")
source ($nu.data-dir | path join "zoxide.nu")

# Nu loads fnox from vendor/autoload after this file. Bootstrap/secrets setup-shell
# generates it explicitly; never perform mise tool lookups during shell startup.
