---@module "wezterm.types.wezterm"
local wezterm = require("wezterm") ---@type Wezterm
local appearance = require("appearance")
local config = wezterm.config_builder() ---@type Config

local is_dark = appearance.is_dark()
if is_dark then
	config.color_scheme = "Catppuccin Mocha"
else
	config.color_scheme = "Catppuccin Latte"
end

config.set_environment_variables = config.set_environment_variables or {}
config.set_environment_variables.WEZTERM_APPEARANCE = is_dark and "dark" or "light"

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

---comment "format-tab-title" callback handler, sets the tab title from the active pane process
---@param tab TabInformation
---@param max_width number
---@return string
local function title_from_pane(
	tab,
	---@diagnostic disable-next-line: unused-local
	max_width
)
	local title = tab.tab_title
	if title and #title > 0 then
		return title
	end

	local process = basename(tab.active_pane.foreground_process_name)
	if process and process ~= "" then
		return " [" .. tab.tab_index .. "] " .. process .. " "
	end

	local pane_title = tab.active_pane.title
	if pane_title and pane_title ~= "" then
		return " [" .. tab.tab_index .. "] " .. pane_title .. " "
	end

	return " [" .. tab.tab_index .. "] "
end

wezterm.on("format-tab-title", function(
	tab, ---@type TabInformation
	---@diagnostic disable-next-line: unused-local
	tabs, ---@type TabInformation[]
	---@diagnostic disable-next-line: unused-local
	panes, ---@type PaneInformation[]
	---@diagnostic disable-next-line: unused-local
	curr_conf, ---@type Config
	---@diagnostic disable-next-line: unused-local
	hover, ---@type boolean
	max_width ---@type number
)
	return title_from_pane(tab, max_width)
end)

wezterm.on("update-right-status", function(
	window,
	---@diagnostic disable-next-line: unused-local
	pane
)
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
		key = "j",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable({
			name = "scroll_mode",
			timeout_milliseconds = 1000,
			one_shot = false,
		}),
	},
	{
		key = "k",
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
		{ key = "Escape", action = wezterm.action.PopKeyTable() },
	},
	window_mode = {
		-- splits
		{
			key = "v",
			action = wezterm.action.SplitVertical({}),
		},
		{
			key = "s",
			action = wezterm.action.SplitHorizontal({}),
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
