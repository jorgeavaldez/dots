# Source first, destination second. Windows directories use junctions.
export def symlink [source: path, destination: path] {
    let source = $source | path expand --strict
    let destination = $destination | path expand --no-symlink
    if $nu.os-info.name == "windows" {
        let flags = if ($source | path type) == "dir" { ["/J"] } else { [] }
        # Delayed expansion keeps %, !, and CMD metacharacters in paths literal.
        # Include quotes in the values so Nu does not escape them as CMD arguments.
        let result = (with-env {
            DOTS_LINK_SOURCE: (['"' $source '"'] | str join)
            DOTS_LINK_DESTINATION: (['"' $destination '"'] | str join)
        } {
            ^$env.ComSpec /d /v:on /c mklink ...$flags "!DOTS_LINK_DESTINATION!" "!DOTS_LINK_SOURCE!" | complete
        })
        if $result.exit_code != 0 {
            error make {msg: $"Could not link ($destination) -> ($source): ($result.stderr | str trim)"}
        }
    } else {
        ^ln -s $source $destination
    }
}
