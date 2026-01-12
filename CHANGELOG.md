# Changelog

System configuration changes and troubleshooting sessions.

Format: Date-based entries with categorized changes. Complex investigations include problem context, diagnosis, and resolution status.

---

## 2026-01-11

### Idle Timeout Freeze Investigation

**Problem:** Screen freezes after idle timeout - no response to input, TTY switching works but unreliable

**Diagnosis in progress:**
- Suspected causes: DPMS + suspend race condition, dual GPU conflict (NVIDIA + AMD iGPU), Hyprland compositor hang on wake
- NVIDIA sleep handler failure detected: `asus_wmi: failed to register LPS0 sleep handler`

**Setup:**
- Added diagnostic logging to hypridle.conf (LOCK_START, DPMS_OFF, SUSPEND_START, etc.)
- Created `~/.local/bin/idle-log.sh` - timestamps all idle events to `/tmp/idle-events.log`
- Created `~/.local/bin/resume-diag.sh` - captures full system state after freeze
- Created `/etc/systemd/system/debug-sleep.service` - logs systemd sleep events

**Status:** Diagnostic logging enabled, waiting to capture a freeze event

### Hyprlock Monitor Fix

**Problem:** Lock screen broken - secondary monitor didn't go black, login dialog invisible, but PIN input still worked

**Diagnosis:** hyprlock.conf referenced old monitor names (DP-1, DP-3) that no longer exist. Actual monitors are DP-6 (primary) and DP-4 (secondary).

**Resolution:**
- Updated hyprlock.conf: DP-1→DP-4 (secondary background), DP-3→DP-6 (all UI elements)
- Updated lock-with-video.sh: monitor DP-3→DP-6, layer top→overlay, added 0.3s delay for mpvpaper init
- Now tracking `~/.local/bin/` scripts in dotfiles repo

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
