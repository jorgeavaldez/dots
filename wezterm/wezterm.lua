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

config.term = 'wezterm'

config.set_environment_variables = config.set_environment_variables or {}
config.set_environment_variables.WEZTERM_APPEARANCE = is_dark and "dark" or "light"

config.font = wezterm.font("JetBrains Mono")
config.font_size = 13
config.max_fps = 120
config.use_fancy_tab_bar = false
config.window_decorations = "RESIZE"
config.notification_handling = "AlwaysShow"

-- Dynamically enabled while the active pane is running pi.
config.enable_kitty_keyboard = false

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

	return tostring(path):gsub("(.*[/\\])", "")
end

local function trim(text)
	if not text then
		return nil
	end

	local trimmed = tostring(text):gsub("^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return nil
	end

	return trimmed
end

local function strip_tab_index_prefix(title)
	return title:gsub("^%s*%[%d+%]%s*", "")
end

local function is_pi_agent_path(value)
	if not value then
		return false
	end

	return tostring(value):find(
		"/npm%-mariozechner%-pi%-coding%-agent/[^/]+/bin/pi$"
	) ~= nil
end

local function process_info_has_pi(process_info)
	if not process_info then
		return false
	end

	if is_pi_agent_path(process_info.executable) or is_pi_agent_path(process_info.name) then
		return true
	end

	local argv = process_info.argv
	if type(argv) == "table" then
		for _, arg in ipairs(argv) do
			if is_pi_agent_path(arg) then
				return true
			end
		end
	end

	return false
end

local function pane_is_running_pi(pane)
	if not pane then
		return false
	end

	if is_pi_agent_path(pane:get_foreground_process_name()) then
		return true
	end

	local ok, process_info = pcall(function()
		return pane:get_foreground_process_info()
	end)
	return ok and process_info_has_pi(process_info)
end

local function update_kitty_keyboard_for_pane(window, pane)
	local enabled = pane_is_running_pi(pane)
	local overrides = window:get_config_overrides() or {}

	if overrides.enable_kitty_keyboard == enabled then
		return
	end

	overrides.enable_kitty_keyboard = enabled
	window:set_config_overrides(overrides)
end

local function is_shell_process(process)
	return process == "zsh"
		or process == "bash"
		or process == "sh"
		or process == "fish"
		or process == "nu"
end

local function cwd_basename(cwd)
	if not cwd then
		return nil
	end

	local path = cwd
	if type(cwd) == "table" then
		path = cwd.file_path or cwd.path
	end

	if not path or path == "" then
		return nil
	end

	path = tostring(path):gsub("[/\\]+$", "")
	return trim(basename(path))
end

local function format_tab_title(tab_index, title)
	if title then
		return " [" .. (tab_index + 1) .. "] " .. title .. " "
	end

	return " [" .. (tab_index + 1) .. "] "
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
	local explicit_title = trim(strip_tab_index_prefix(tab.tab_title or ""))
	if explicit_title then
		return format_tab_title(tab.tab_index, explicit_title)
	end

	local pane = tab.active_pane
	local process = trim(basename(pane.foreground_process_name))
	local pane_title = trim(pane.title)

	if process and not is_shell_process(process) then
		return format_tab_title(tab.tab_index, pane_title or process)
	end

	local cwd = cwd_basename(pane.current_working_dir)
	if cwd then
		return format_tab_title(tab.tab_index, cwd)
	end

	if process then
		return format_tab_title(tab.tab_index, process)
	end

	if pane_title and pane_title ~= "wezterm" then
		return format_tab_title(tab.tab_index, pane_title)
	end

	return format_tab_title(tab.tab_index)
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

wezterm.on("update-status", function(window, pane)
	update_kitty_keyboard_for_pane(window, pane)

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
	-- Let pi receive Alt+Enter instead of WezTerm's default fullscreen toggle.
	{
		key = "Enter",
		mods = "ALT",
		action = wezterm.action.DisableDefaultAssignment,
	},
	-- shift+enter
	{
		key = "Enter",
		mods = "SHIFT",
		action = wezterm.action.SendString("\x1b[200~\n\x1b[201~"),
	},
}

---comment prompt callback handler, sets an explicit title for the current tab
---@param window Window
---@param pane Pane
---@param line string?
local function rename_current_tab(
	window,
	---@diagnostic disable-next-line: unused-local
	pane,
	line
)
	local title = trim(line)
	if not title then
		return
	end

	window:active_tab():set_title(title)
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
