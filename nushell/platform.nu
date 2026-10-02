# Musl Nu reports linux in Termux; native Nu reports android.
export def termux [] {
    $nu.os-info.name == "android" or ($env.TERMUX_VERSION? | default "" | is-not-empty) or ($env.PREFIX? | default "" | str contains "com.termux")
}

# Shared by bootstrap, startup and explicit secrets integration generation.
export def --env android-mise [] {
    if not (termux) { return }
    if $env.MISE_GLOBAL_CONFIG_FILE? != null {
        error make {msg: "MISE_GLOBAL_CONFIG_FILE suppresses Android overlays. Preserve that override, or explicitly unset it and use MISE_CONFIG_DIR before Termux setup/startup."}
    }
    if ($env.MISE_AUTO_ENV? | default "1" | into string) in ["0" "false"] {
        error make {msg: "Termux requires the Android mise overlay. Explicit MISE_AUTO_ENV disables it; unset that override before setup/startup."}
    }
    $env.MISE_AUTO_ENV = ($env.MISE_AUTO_ENV? | default "1")
    $env.XDG_DATA_HOME = ($env.XDG_DATA_HOME? | default ($nu.home-dir | path join ".local" "share"))
}
