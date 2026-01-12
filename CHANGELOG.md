# Changelog

System configuration changes and troubleshooting sessions.

Format: Date-based entries with categorized changes. Complex investigations include problem context, diagnosis, and resolution status.

---

## 2026-01-11

### Wallpaper Setup

- Switched from hyprpaper to swaybg (hyprpaper was crashing)
- Added dual-monitor spanning wallpaper using split images
- Config: `exec-once = swaybg -o DP-6 -i .../nebula-left.png` and `DP-4` with right half

### Boot Time Investigation

**Problem:** System boot taking ~2 minutes (70+ seconds in kernel phase before systemd starts)

**Diagnosis:**
- USB port 1-11 failing to enumerate with repeated timeouts (error -110, -71)
- Port 1-11 is internal USB header for Corsair H100i Elite AIO pump LCD
- AIO USB cable not connected (need extender to reach motherboard header)
- Motherboard: ASUS ROG STRIX X870-A GAMING WIFI

**Actions taken:**
- Analyzed boot with `systemd-analyze blame` and `dmesg`
- Identified USB enumeration as the bottleneck
- Rebuilt initramfs (`mkinitcpio -P`)

**Status:** Pending - will fully resolve once AIO USB is connected. Workaround available: reduce timeout via `usbcore.initial_descriptor_timeout=500` kernel parameter.

### SDDM Display Manager

- Configured SDDM with Wayland backend using Weston kiosk compositor
- `/etc/sddm.conf.d/theme.conf` - elarun theme, numlock enabled
- `/etc/sddm.conf.d/wayland.conf.bak` - Wayland compositor config (backup)

### Dotfiles Structure

- Added `/etc/` tracking for system-level configs
- Now tracking: SDDM configuration

### Packages

- Installed KDE Plasma components: kwin, breeze, layer-shell-qt, kscreenlocker, libkscreen, libplasma
- Installed Qt6/GStreamer multimedia plugins
- Updated package lists (87 official, 5 AUR)
