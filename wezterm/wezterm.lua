local wezterm = require("wezterm") ---@type Wezterm
local appearance = require("appearance")
local config = wezterm.config_builder() ---@type Config

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
config.notification_handling = "AlwaysShow"

-- required by pi https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#terminal-setup
config.enable_kitty_keyboard = true

-- custom key binds
config.leader = {
	key = ";",
	mods = "CTRL",
	timeout_milliseconds = 1000,
}

local function basename(path)
	if not path then
		return nil
	end

	return path:gsub("(.*[/\\])", "")
end

local function title_from_pane(pane, tab_index)
	local process = basename(pane:get_foreground_process_name())
	if process and process ~= "" then
		return process
	end

	local title = pane:get_title()
	if title and title ~= "" then
		return title
	end

	return "Tab " .. (tab_index + 1)
end

wezterm.on("format-tab-title", function(tab)
	return title_from_pane(tab.active_pane, tab.tab_index)
end)

wezterm.on("update-right-status", function(window, pane)
	local name = window:active_key_table()
	if name then
		name = "TABLE: " .. name
	end
	window:set_right_status(name or "")
end)

config.keys = {
	{
		key = "t",
		mods = "LEADER",
		action = wezterm.action.SpawnTab("CurrentPaneDomain"),
	},
	-- windows/splits/panes
	{
		key = "w",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable({
			name = "window_mode",
			one_shot = true,
		}),
	},
	-- scroll
	{
		key = "J",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable({
			name = "scroll_mode",
			timeout_milliseconds = 1000,
			one_shot = false,
		}),
	},
	{
		key = "K",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable({
			name = "scroll_mode",
			one_shot = false,
		}),
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
		{ key = "Escape", action = "PopKeyTable" },
	},
	window_mode = {
		-- splits
		{
			key = "v",
			action = wezterm.action.SplitVertical,
		},
		{
			key = "s",
			action = wezterm.action.SplitHorizontal,
		},
		-- navigate between splits
		{
			key = "h",
			action = wezterm.action.ActivatePaneDirection("Left"),
		},
		{
			key = "j",
			action = wezterm.action.ActivatePaneDirection("Down"),
		},
		{
			key = "k",
			action = wezterm.action.ActivatePaneDirection("Up"),
		},
		{
			key = "l",
			action = wezterm.action.ActivatePaneDirection("Right"),
		},
		{
			key = "x",
			action = wezterm.action.CloseCurrentPane({ confirm = true }),
		},
	},
}

return config
