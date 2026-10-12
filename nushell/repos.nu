export def url [repo_name?: string]: nothing -> string {
    $repo_name
    | default {
        pwd | path basename
    }
    | gh repo view $in --json sshUrl
    | from json
    | get sshUrl
}

export def clone [repo_name?: string]: nothing -> string {
    url $repo_name
    | jj git clone $in
}
