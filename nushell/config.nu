# Shared interactive config for Windows, macOS, and Linux.
$env.config.show_banner = false

alias j = ^jj
alias js = ^jj st
alias jd = ^jj diff
alias psh = ^jj git push
alias n = ^nvim
alias e = ^nvim
alias c = clear
alias l = ls --all --long
alias h = herdr
# Replace Nu to reload startup files; temporary variables/definitions are lost.
alias reload = exec nu

const links_module = path self | path expand | path dirname | path join "links.nu"
use $links_module symlink

# Remove only links, never their targets or ordinary files/directories.
def rmsymlink [link: path] {
    let link = ($link | path expand --no-symlink)
    if ($link | path type) != "symlink" {
        error make {msg: $"Not a symlink or junction: ($link)"}
    }
    rm $link
}

def --env proj [] {
    cd ("~" | path expand | path join "proj")
}

use ($nu.cache-dir | path join "mise.nu")
source ($nu.data-dir | path join "zoxide.nu")
