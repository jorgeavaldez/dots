local wezterm = require("wezterm") ---@type Wezterm

local module = {}

function module.is_dark()
    if wezterm.gui then
        local a = wezterm.gui.get_appearance()
        return a:find("Dark")
    end
    return true
end

return module
