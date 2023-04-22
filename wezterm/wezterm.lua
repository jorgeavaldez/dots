local wezterm = require "wezterm"

local config = {}

if wezterm.config_builder then
    config = wezterm.config_builder()
end

config.color_scheme = 'Oxocarbon Dark';
-- config.color_scheme = "tokyonight"
config.font = wezterm.font "JetBrains Mono";

config.use_fancy_tab_bar = false;

config.window_decorations = "INTEGRATED_BUTTONS|RESIZE";
config.window_frame = { border_top_height = "0.5cell" };
config.colors = {
    tab_bar = {
        -- this is to match the oxocarbon dark color since otherwise it looks weird with the top buttons
        -- https://github.com/nyoom-engineering/base16-oxocarbon/tree/f6944a9536b1e2f2879a32e49b104b2b4c09dfe0
        background = "#161616",
    },
};

-- custom key binds
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
