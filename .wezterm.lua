local wezterm = require("wezterm")

local config = wezterm.config_builder()

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
	pane:send_text("fastfetch\n") -- Run fastfetch only in the first window
end)

-- setup for transparent background
config.window_background_opacity = 0.6
config.macos_window_background_blur = 5

-- Set the default size
config.initial_cols = 120
config.initial_rows = 36

-- Higher max fps (double usual)
config.max_fps = 120

-- custom font for editor
config.font_dirs = { "~/.local/share/fonts/NerdFonts" }
config.font = wezterm.font("Roboto Mono Nerd Font")
config.warn_about_missing_glyphs = false

-- font text size
config.font_size = 12

-- can resize term - but no titles or unnecessary headers/ icons
config.window_decorations = "RESIZE"

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

--custom colour scheme
config.color_scheme = "Flat (base16)"

config.front_end = "WebGpu"
config.webgpu_power_preference = "LowPower"
config.animation_fps = 120
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"
-- Key mappings
config.keys = {
	{ key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
	{ key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
	{ key = "t", mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "t", mods = "ALT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = true }) },
	{ key = "w", mods = "ALT", action = wezterm.action.CloseCurrentTab({ confirm = true }) },
	{ key = "n", mods = "ALT", action = wezterm.action.SpawnWindow },
	{ key = "h", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "l", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "j", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "LeftArrow", mods = "ALT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "RightArrow", mods = "ALT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "DownArrow", mods = "ALT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "UpArrow", mods = "ALT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "q", mods = "ALT", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	{ key = "1", mods = "ALT", action = wezterm.action.ActivateTab(0) },
	{ key = "2", mods = "ALT", action = wezterm.action.ActivateTab(1) },
	{ key = "3", mods = "ALT", action = wezterm.action.ActivateTab(2) },
	{ key = "4", mods = "ALT", action = wezterm.action.ActivateTab(3) },
	{ key = "5", mods = "ALT", action = wezterm.action.ActivateTab(4) },
	{ key = "6", mods = "ALT", action = wezterm.action.ActivateTab(5) },
	{ key = "7", mods = "ALT", action = wezterm.action.ActivateTab(6) },
	{ key = "8", mods = "ALT", action = wezterm.action.ActivateTab(7) },
	{ key = "9", mods = "ALT", action = wezterm.action.ActivateTab(8) },
	{ key = "+", mods = "CTRL|SHIFT", action = "IncreaseFontSize" },
	{ key = "-", mods = "CTRL|SHIFT", action = "DecreaseFontSize" },
	{ key = "0", mods = "CTRL|SHIFT", action = "ResetFontSize" },
}

return config
