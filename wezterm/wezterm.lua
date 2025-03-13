local wezterm = require("wezterm")
local appearance = require("appearance")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

if appearance.is_dark() then
	config.color_scheme = "Catppuccin Mocha"
else
	config.color_scheme = "Catppuccin Latte"
end

config.font = wezterm.font("JetBrains Mono")
config.font_size = 12
config.max_fps = 120

config.use_fancy_tab_bar = false

-- idk if i want the top buttons yet since it looks cleaner with full screen term window in vscode
-- config.window_decorations = "INTEGRATED_BUTTONS|RESIZE";
config.window_decorations = "RESIZE"
config.window_frame = { border_top_height = "0.5cell" }

--[[
config.colors = {
    tab_bar = {
        -- this is to match the oxocarbon dark color since otherwise it looks weird with the top buttons
        -- https://github.com/nyoom-engineering/base16-oxocarbon/tree/f6944a9536b1e2f2879a32e49b104b2b4c09dfe0
        background = "#161616",
    },
};
--]]

-- custom key binds
config.leader = {
	key = "'",
	mods = "CTRL",
	timeout_milliseconds = 1000,
}

config.keys = {
	{
		key = "t",
		mods = "LEADER",
		action = wezterm.action.SpawnTab("CurrentPaneDomain"),
	},
	{
		key = "v",
		mods = "LEADER",
		action = wezterm.action.SplitVertical,
	},
	{
		key = "h",
		mods = "LEADER",
		action = wezterm.action.SplitHorizontal,
	},
}

return config
