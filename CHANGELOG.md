# Changelog

System configuration changes and troubleshooting sessions.

Format: Date-based entries with categorized changes. Complex investigations include problem context, diagnosis, and resolution status.

---

## 2026-01-12

### Monitor Port Configuration Fix

**Problem:** Monitor settings (left/right position, 1.5x scaling on AOC 4K) kept reverting on every reboot. Monitors would swap positions and lose scaling.

**Diagnosis:**
- System has both AMD Ryzen iGPU and NVIDIA RTX GPU
- On different boots, monitors would land on different GPU's ports:
  - NVIDIA (card2): DP-4, DP-6
  - AMD iGPU (card1): DP-1, DP-3
- Hyprland config referenced specific port names, which changed unpredictably
- Additionally, `~/.config/hypr/` was a regular directory (not symlink), owned by root

**Fix applied:**
1. Disabled AMD iGPU in BIOS - NVIDIA is now the only display controller
2. With iGPU disabled, NVIDIA becomes card1 with stable ports: DP-1 (ASUS), DP-3 (AOC)
3. Updated hyprland.conf: `monitor=DP-3,preferred,0x0,1.5` and `monitor=DP-1,preferred,2560x0,auto`
4. Updated swaybg wallpaper commands to use DP-3/DP-1
5. Fixed ownership: `chown -R travis:travis ~/dotfiles/.config/hypr/`
6. Created proper symlink: `~/.config/hypr` → `~/dotfiles/.config/hypr`

**Status:** Resolved. Monitor config now persists across reboots.

---

### Suspend/Resume Fix - NVIDIA Configuration

**Problem:** System suspends but doesn't resume - black screen with fans running, requires hard power off

**Diagnosis:**
- Suspend was working after NVIDIA 590.48.01 driver install
- Broke after DM testing (SDDM, Weston, KWin) on Jan 11
- This was a configuration regression, not a driver bug
- KWin installation brought in 21 plasma packages that may have conflicted with Hyprland display handling
- NVIDIA modules were not early-loaded via mkinitcpio (race condition risk on resume)

**Fix applied (Phase 1):**
- Added NVIDIA modules to `/etc/mkinitcpio.conf`: `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`
- Removed kwin and 21 plasma dependencies (aurorae, breeze, kdecoration, kscreenlocker, libkscreen, libplasma, etc.)
- Cleaned up KDE config files (~/.config/kwinrc, powerdevilrc, powermanagementprofilesrc)
- Rebuilt initramfs with `mkinitcpio -P`

**Fix applied (Phase 2 - fans stayed on, system never entered deep sleep):**
- Root cause: System stuck in s2idle (shallow freeze) instead of S3 deep sleep
- Fans staying on = system never actually suspends, just freezes display
- Added `mem_sleep_default=deep` kernel parameter to `/etc/default/grub`
- Regenerated GRUB config
- Result: Did NOT fix the issue

**Fix applied (Phase 3 - ACPI firmware bug on AM5/X870):**
- Research confirmed this is a known AM5/X870 ACPI firmware bug affecting multiple vendors
- Modern AM5 motherboard DSDT tables have Windows-specific code paths that break S3 on Linux
- Sources: [Arch Wiki](https://wiki.archlinux.org/title/Wakeup_triggers), [CachyOS Forum](https://discuss.cachyos.org/t/suspend-to-ram-s3-fails-immediate-wake-or-hang-during-suspend-x870-aorus-elite-wifi-cachyos/14366)
- Added `acpi_osi="!Windows 2015"` kernel parameter to `/etc/default/grub`
- This tells ACPI firmware that Linux is NOT Windows 10, triggering different (working) code paths
- Regenerated GRUB config

**Status:** Pending verification - fans should STOP when suspended (proves S3 working)

---

### Hyprland Keybinds

- Added `SUPER+O` → launch Obsidian

---

### OpenRGB RAM Sleep Configuration

**Problem:** RAM RGB (Corsair Dominator Platinum x4) stays lit during sleep while other RGB turns off

**Setup:**
- Installed OpenRGB from AUR
- Loaded i2c-dev and i2c-piix4 kernel modules (AMD system)
- Created systemd sleep hook to turn off RAM RGB before suspend
- Detected devices: 4x Corsair Dominator Platinum, iCUE Link System Hub, ASUS ROG STRIX X870-A, G502 mouse

**Files created:**
- `/etc/modules-load.d/i2c.conf` - persistent i2c module loading
- `/etc/systemd/system/rgb-sleep.service` - sleep hook service
- `/usr/local/bin/rgb-sleep-hook.sh` - script to turn off RAM RGB

**Status:** Pending verification - sleep/suspend may have broader configuration issues to investigate

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
- Rebuilt initramfs (`mkinitcpio -P`) - no effect, confirms kernel-level issue

**Status:** Pending - need USB cable extender to connect AIO. Workaround: reduce timeout via `usbcore.initial_descriptor_timeout=500` kernel parameter.

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
