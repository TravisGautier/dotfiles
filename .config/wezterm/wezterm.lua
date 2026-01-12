local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Font settings
config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 11.0

-- Color scheme with Claude vibes
config.color_scheme = 'Catppuccin Mocha'

-- Enable 24-bit color
config.term = 'xterm-256color'

-- Scrollback
config.scrollback_lines = 50000

-- Window appearance
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}
config.window_background_opacity = 0.95
config.hide_tab_bar_if_only_one_tab = true

-- Fix rendering issues on resize
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'

-- Cursor
config.default_cursor_style = 'SteadyBar'

-- Right-click paste (like traditional terminals)
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- Keybindings
config.keys = {
  -- Ctrl+Shift+E to equalize all panes
  {
    key = 'e',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.Multiple {
      wezterm.action.AdjustPaneSize { 'Left', 9999 },
      wezterm.action.AdjustPaneSize { 'Right', 9999 },
      wezterm.action.AdjustPaneSize { 'Up', 9999 },
      wezterm.action.AdjustPaneSize { 'Down', 9999 },
    },
  },
  -- Easier pane navigation with Alt+Arrow
  { key = 'LeftArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Down' },
  -- Easy splits
  { key = '\\', mods = 'CTRL|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'CTRL|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
}

-- Launch in 2x2 grid layout
wezterm.on('gui-startup', function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})

  -- Split right to get left/right (50% each)
  local right_pane = pane:split { direction = 'Right', size = 0.5 }

  -- Split each side vertically (50% each)
  pane:split { direction = 'Bottom', size = 0.5 }
  right_pane:split { direction = 'Bottom', size = 0.5 }
end)

return config
