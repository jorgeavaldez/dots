local wezterm = require "wezterm"

local config = {}


if wezterm.config_builder then
    config = wezterm.config_builder()
end

config.color_scheme = "tokyonight"
config.font = wezterm.font "JetBrains Mono";

config.use_fancy_tab_bar = false;

--[[
config.leader = {
    key = ";",
    mods = "CTRL",
    timeout_milliseconds = 1000,
};

config.keys = {
    {
        key = "t",
        mods = "LEADER",
        action = wezterm.action.SpawnTab "CurrentPaneDomain",
    },
};
--]]

return config
