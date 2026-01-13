# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Overview

Hyprland-based Arch Linux desktop environment with dual monitors (AOC 4K + ASUS curved), NVIDIA RTX GPU (iGPU disabled in BIOS), and catppuccin-mocha theming.

## Monitor Setup

```
DP-3 (AOC U32V3 4K)    - Left, position 0x0, scaled 1.5x
DP-1 (ASUS VG32VQ1B)   - Right, position 2560x0, native res
```

**Important:** Monitor port names are tied to the NVIDIA GPU. The AMD iGPU is disabled in BIOS to prevent port assignment conflicts.

## Dotfiles Architecture

This repo uses **symlinks** for config management:
- `~/.config/hypr` → `~/dotfiles/.config/hypr` (symlink)
- Shell dotfiles (`.bashrc`, `.zshrc`, etc.) → symlinked to repo
- `/etc/` configs are tracked but require manual `sudo cp` to apply

Run `./install.sh` to set up symlinks on a new system.

## Key Commands

```bash
# Restore to new system
./install.sh

# Install packages
sudo pacman -S --needed - < packages-official.txt
yay -S --needed - < packages-aur.txt

# Update package lists
pacman -Qqe > packages-official.txt
pacman -Qqm > packages-aur.txt

# Hyprland
hyprctl monitors          # List monitors with port names
hyprctl reload            # Reload config without restart
hyprctl clients           # List windows
```

## Core Components

| Component | Tool | Config |
|-----------|------|--------|
| WM | Hyprland (dwindle) | `.config/hypr/hyprland.conf` |
| Bar | Waybar | `.config/waybar/config.jsonc`, `style.css` |
| Terminal | Kitty | `.config/kitty/kitty.conf` |
| Launcher | hyprlauncher | SUPER+R |
| Lock | hyprlock | `.config/hypr/hyprlock.conf` |
| Idle | hypridle | `.config/hypr/hypridle.conf` |
| Wallpaper | swaybg | exec-once in hyprland.conf |

## Key Keybindings (SUPER = Windows key)

| Keys | Action |
|------|--------|
| SUPER+Q | Terminal (kitty) |
| SUPER+R | App launcher |
| SUPER+F | Firefox |
| SUPER+C | Close window |
| SUPER+L | Lock screen |
| SUPER+M | Logout menu |
| SUPER+1-0 | Switch workspace |

## NVIDIA Configuration

Required env vars in hyprland.conf:
```
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
```

NVIDIA modules early-loaded in `/etc/mkinitcpio.conf`:
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

## Changelog

See `CHANGELOG.md` for configuration history and troubleshooting sessions. **Always update changelog before committing significant changes.**

Format:
- Date header: `## YYYY-MM-DD`
- Category: `### Component Name`
- For debugging: Problem, Diagnosis, Status sections
