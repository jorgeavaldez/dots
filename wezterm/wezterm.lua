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
config.font_size = 13
config.max_fps = 120
config.use_fancy_tab_bar = false
config.window_decorations = "RESIZE"

-- custom key binds
config.leader = {
	key = ";",
	mods = "CTRL",
	timeout_milliseconds = 1000,
}

wezterm.on('update-right-status', function(window, pane)
	local name = window:active_key_table()
	if name then
		name = 'TABLE: ' .. name
	end
	window:set_right_status(name or '')
end)

config.keys = {
	{
		key = "t",
		mods = "LEADER",
		action = wezterm.action.SpawnTab("CurrentPaneDomain"),
	},
	-- splits
	{
		key = "v",
		mods = "LEADER|CTRL",
		action = wezterm.action.SplitVertical,
	},
	{
		key = "h",
		mods = "LEADER|CTRL",
		action = wezterm.action.SplitHorizontal,
	},
	-- navigate between splits
	{
		key = "h",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "j",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},
	{
		key = "k",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
	-- scroll
	{
		key = "J",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable {
			name = "scroll_mode",
			timeout_milliseconds = 1000,
			one_shot = false,
		},
	},
	{
		key = "K",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable {
			name = "scroll_mode",
			one_shot = false,
		},
	},
}

config.key_tables = {
	scroll_mode = {
		{
			key = "J",
			action = wezterm.action.ScrollByLine(1),
		},
		{
			key = "K",
			action = wezterm.action.ScrollByLine(-1),
		},
		{ key = 'Escape', action = 'PopKeyTable' },
	}
}

return config
