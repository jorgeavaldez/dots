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
	local pane_title = tab.active_pane.title
	if pane_title and pane_title ~= "" then
		return " [" .. tab.tab_index + 1 .. "] " .. pane_title .. " "
	end

	local process = basename(tab.active_pane.foreground_process_name)
	if process and process ~= "" then
		return " [" .. tab.tab_index + 1 .. "] " .. process .. " "
	end

	return " [" .. tab.tab_index + 1 .. "] "
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
		action = wezterm.action.ActivateKeyTable({
			name = "tabs_mode",
			one_shot = true,
		}),
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

---comment "format-tab-title" callback handler, sets the tab title from the active pane process
---@param window Window
---@param pane Pane
---@param line string?
local function rename_current_tab(
	window,
	---@diagnostic disable-next-line: unused-local
	pane,
	line
)
	if line == nil or line == "" or line:gsub("^%s*(.-)%s*$", "%1") == "" then
		return
	end

	local curr_tab = window:active_tab()
	local curr_tab_id = curr_tab:tab_id()
	local all_tabs = window:mux_window():tabs_with_info()

	local tab_id = nil
	for _, tab in ipairs(all_tabs) do
		if tab.tab:tab_id() == curr_tab_id then
			tab_id = tab.index
		end
	end

	local tab_prefix_name = " " .. line:gsub("^%s*(.-)%s*$", "%1") .. " "

	if tab_id ~= nil then
		tab_prefix_name = " [" .. (tab_id + 1) .. "]" .. tab_prefix_name
	end

	window:active_tab():set_title(tab_prefix_name)
end

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
		---@diagnostic disable-next-line: assign-type-mismatch
		{ key = "Escape", action = wezterm.action.PopKeyTable },
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
	tabs_mode = {
		{
			key = "l",
			---@diagnostic disable-next-line: assign-type-mismatch
			action = wezterm.action.ShowTabNavigator,
		},
		{
			key = "c",
			action = wezterm.action.SpawnTab("CurrentPaneDomain"),
		},
		{
			key = "q",
			action = wezterm.action.CloseCurrentTab({ confirm = true }),
		},
		{
			key = "n",
			action = wezterm.action.ActivateTabRelative(1),
		},
		{
			key = "p",
			action = wezterm.action.ActivateTabRelative(-1),
		},
		{
			key = "o",
			---@diagnostic disable-next-line: assign-type-mismatch
			action = wezterm.action.ActivateLastTab,
		},
		{
			key = "r",
			action = wezterm.action.PromptInputLine({
				description = "Enter tab name",
				action = wezterm.action_callback(rename_current_tab),
			}),
		},
	},
}

return config
