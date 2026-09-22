-- Real Lua evaluation with a minimal WezTerm API stand-in, no GUI required.
local root = assert(arg[1], "pass the checkout root")
local actual_getenv = os.getenv
local function load_config(triple, env)
    os.getenv = function(key)
        return env[key]
    end
    package.loaded.wezterm = {
        target_triple = triple,
        config_builder = function() return {} end,
        font = function(name) return name end,
        on = function() end,
        action_callback = function(callback) return callback end,
        action = setmetatable({}, { __index = function() return function() end end }),
    }
    package.loaded.appearance = { is_dark = function() return true end }
    local result = dofile(root .. "/wezterm/wezterm.lua")
    os.getenv = actual_getenv
    return result
end

local linux = load_config("x86_64-unknown-linux-gnu", { HOME = "/home/test", PATH = "/usr/bin" })
assert(linux.default_prog[1] == "nu")
assert(linux.set_environment_variables.PATH == "/home/test/.local/bin:/home/test/.local/share/mise/shims:/usr/bin")
assert(linux.set_environment_variables.SSH_AUTH_SOCK == nil)
local xdg = load_config("aarch64-unknown-linux-gnu", {
    HOME = "/home/test", PATH = "/usr/bin", XDG_DATA_HOME = "/data",
})
assert(xdg.set_environment_variables.PATH == "/home/test/.local/bin:/data/mise/shims:/usr/bin")
local custom = load_config("x86_64-unknown-linux-gnu", {
    HOME = "/home/test", PATH = "/usr/bin", XDG_DATA_HOME = "/data", MISE_DATA_DIR = "/tools",
})
assert(custom.set_environment_variables.PATH == "/home/test/.local/bin:/tools/shims:/usr/bin")
local mac = load_config("aarch64-apple-darwin", { HOME = "/Users/test", PATH = "/usr/bin" })
assert(mac.default_prog[1] == "nu")
assert(mac.set_environment_variables.PATH:find("/opt/homebrew/bin", 1, true))
local windows = load_config("x86_64-pc-windows-msvc", {})
assert(windows.default_prog[1] == "nu.exe")
assert(windows.mux_enable_ssh_agent == false)
print("WezTerm config: Linux/default/XDG/custom mise, macOS, Windows passed")
