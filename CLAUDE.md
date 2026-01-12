# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Overview

Hyprland-based Arch Linux desktop environment with dual monitors (AOC 4K + ASUS curved), NVIDIA GPU, and catppuccin-mocha theming.

## Key Keybindings (SUPER = Windows key)

| Keys | Action |
|------|--------|
| SUPER+Q | Terminal (kitty) |
| SUPER+R | App launcher (hyprlauncher) |
| SUPER+E | File manager (dolphin) |
| SUPER+F | Firefox |
| SUPER+C | Close window |
| SUPER+M | Logout menu (wlogout) |
| SUPER+L | Lock screen |
| SUPER+V | Toggle floating |
| SUPER+1-0 | Switch workspace |
| SUPER+SHIFT+1-0 | Move window to workspace |

## Monitor Setup

```
DP-3 (AOC 4K) - Left, scaled 1.5x
DP-1 (ASUS)   - Right, native res
```

## Core Components

- **WM**: Hyprland (dwindle layout)
- **Bar**: Waybar (top, minimal)
- **Terminal**: Kitty (catppuccin-mocha theme)
- **Launcher**: hyprlauncher
- **Lock**: hyprlock + mpvpaper video background
- **Idle**: hypridle (lock 5min, dpms off 10min, suspend 15min)

## Config Locations

| Component | Config Path |
|-----------|-------------|
| Hyprland | `~/.config/hypr/hyprland.conf` |
| Waybar | `~/.config/waybar/config.jsonc`, `style.css` |
| Kitty | `~/.config/kitty/kitty.conf` |
| Idle/Lock | `~/.config/hypr/hypridle.conf`, `hyprlock.conf` |
| Lock script | `~/.local/bin/lock.sh` |

## Dotfiles Commands

```bash
# Restore to new system
./install.sh

# Install packages
sudo pacman -S --needed - < packages-official.txt
yay -S --needed - < packages-aur.txt

# Update package lists
pacman -Qqe > packages-official.txt
pacman -Qqm > packages-aur.txt
```

## NVIDIA Environment

Required env vars are set in hyprland.conf:
- `LIBVA_DRIVER_NAME=nvidia`
- `GBM_BACKEND=nvidia-drm`
- `__GLX_VENDOR_LIBRARY_NAME=nvidia`

## Audio

PipeWire/WirePlumber via `wpctl`:
```bash
wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+   # Volume up
wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-   # Volume down
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle  # Mute toggle
```

## Useful Hyprland Commands

```bash
hyprctl monitors          # List monitors
hyprctl clients           # List windows
hyprctl dispatch dpms off # Screens off
hyprctl reload            # Reload config
```
