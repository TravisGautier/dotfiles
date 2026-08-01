# Changelog

System configuration changes and troubleshooting sessions.

Format: Date-based entries with categorized changes. Complex investigations include problem context, diagnosis, and resolution status.

---

## 2026-07-31

### Investigation: "Screensaver never clears off AOC monitor after unlock" — solved, no reboot needed

**Problem:** After unlocking, DP-3 (AOC 4K) sometimes stayed on the lock-video "screensaver" while DP-1 worked normally; only known recourse was a reboot. Frequency went from ~monthly to multiple times/week after the 2026-07-26 update (hyprland 0.56.0, hyprlock 0.9.6, nvidia 610.43.03, mpvpaper 1.9).

**Diagnosis (performed live on a broken session):**
- Both lock scripts start an mpvpaper video overlay on DP-3, run hyprlock, and killed mpvpaper only after hyprlock exited.
- hyprlock 0.9.6 intermittently deadlocks on exit after a *successful* unlock (all 3 threads in futex waits; logind `LockedHint` already `no`). Correlates with unlock racing the DPMS-on modeset — Hyprland log showed both monitors releasing/re-acquiring CRTCs at wake.
- Because hyprlock never exits, the cleanup `kill $MPVPAPER_PID` never runs → orphaned mpvpaper overlay covers DP-3 forever. Desktop underneath is fine. Recovery = kill mpvpaper + `kill -9` hyprlock. **A reboot was never necessary.**

**Fixes applied:**
- `lock.sh` + `lock-with-video.sh`: cleanup moved to `trap ... EXIT`; added unlock watchdog that polls `loginctl show-session $XDG_SESSION_ID -p LockedHint` and `kill -9`s hyprlock if the hint goes yes→no but the process is still alive 5s later (fail-safe: inert if the hint is never set).
- New `~/.local/bin/unstick-lockscreen.sh` panic button bound to **SUPER+SHIFT+L**: `pkill -x mpvpaper; pkill -9 -x hyprlock; hyprctl dispatch dpms on`.
- `hyprlock.conf`: `animations { animation = fadeOut, 0 }` — the exit fade waiting on frame callbacks during the DPMS-on modeset is the likely deadlock site.

### lock.sh: removed 10-minute suspend timer

Re-investigated whether suspend was fixed since the 2026-01-20 audit. It was not — it got worse:
- [open-gpu-kernel-modules #1117](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1117): RTX 50-series (Blackwell) s2idle resume hangs on kernel 7.x (works on 6.17); still open as of April 2026. We run kernel 7.1.5 + 5070 Ti.
- Deep/S3 remains firmware-broken on AM5/X870.
- Journal shows a Jun 01 2026 suspend attempt aborted at `xhci_pci_suspend returns -110` (USB controller timeout) — likely triggered by this very lock.sh timer and likely one of the past forced power-offs.
- Local misconfig: `nvidia-suspend/resume/hibernate.service` are disabled while `NVreg_PreserveVideoMemoryAllocations=1` is set; that combo breaks resume even when the platform cooperates. If suspend is ever revisited (after #1117), enable those services too.

**Status:** Fixes live (`hyprctl reload` done). Pending real-world verification on next few lock/unlock cycles — check `hyprctl layers` for stale mpvpaper after unlock, `/tmp/idle-events.log` for history.

### Sync: bashrc + package lists

- `.bashrc`: synced live additions — `CLAUDE_CODE_TMPDIR=~/.cache/claude-tmp`, `~/.local/bin` on PATH, and the commented-out 2026-05-30 streaming-incident mitigations (reverted 2026-06-01).
- Package lists refreshed. New official: efitools, mokutil, sbctl, sbsigntools, zip (Secure Boot tooling). New AUR: shim-signed, mpvpaper-debug, webkit2gtk-debug, libsoup. Removed: steam, yay-debug.

## 2026-05-24

### Investigation: OOM cascade forced hard shutdown

**Problem:** Around 00:48 CDT on 2026-05-24, multiple concurrent `claude` sessions (running as root via `sudo -E /usr/bin/claude`) combined with Node/npm/tsc/jest/Firefox/Docker exhausted RAM. The kernel OOM-killer fired repeatedly and eventually reaped the user's `kitty-*.scope`, leaving the desktop unresponsive. Travis hard-power-cycled and booted from an Arch USB before re-entering the installed system.

**Diagnosis:**
- Hardware healthy: both NVMes pass SMART (nvme0n1 at 2% wear, 0 media errors; 21 unsafe shutdowns logged historically). Btrfs reports zero device/corruption/scrub errors.
- Root cause was layered: zram-only swap (no on-disk overflow), no userspace OOM daemon, `user-1000.slice` had `MemoryMax=infinity` (unbounded), no per-claude memory grouping, claude was aliased to `sudo -E /usr/bin/claude` (uid 0 — but cgroup still under user.slice).
- partymasters package.json ships `NODE_OPTIONS=--max-old-space-size=8192` for typecheck and `4096` for build/test. A worktree-claude can spike to ~12–16 GiB. The 75-GB-VSZ processes in the OOM log were jest/tsc workers, not claude itself.
- Travis runs up to 8 concurrent worktree-claudes; 8 × 16 GiB exceeds the 62 GiB of RAM by design.

**Status:** Resolved. Layered hardening applied (live; survives reboot):

### Shell: claude wrapper function

- Replaced `alias claude='sudo -E /usr/bin/claude'` with a function that wraps each invocation in a transient systemd scope under a dedicated `claude.slice`, owned by the user-1000 systemd manager (`user@1000.service`). Each scope is individually targetable by `systemd-oomd`, so a runaway claude can be killed in isolation without taking down the others or the desktop session.
- Final form:
  ```bash
  claude() {
    systemd-run --user --scope --slice=claude.slice --quiet -- sudo -E /usr/bin/claude "$@"
  }
  ```
- Important architectural detail (verified empirically via cgroup probe): `sudo systemd-run --scope` (which I initially proposed) creates the scope in the **system manager**, landing it at `/system.slice/claude.slice/...` — outside `user-1000.slice`, so the user-slice cap would not apply. The correct form is `systemd-run --user --scope` first, then `sudo` inside the scope. Arch's `/etc/pam.d/sudo` does not load `pam_systemd`, so sudo doesn't reparent cgroups; the elevated process stays in the user-manager-owned scope.

### Waybar: style.css formatting

- Live had two separate `0% { opacity: 1.0; }` and `100% { opacity: 1.0; }` rules; repo had the merged `0%, 100% { opacity: 1.0; }` form. Pushed live → repo to capture current running state. (Cosmetic only; CSS-equivalent.)

### System hardening (out-of-scope for this repo — documented for reference)

These changes are in `/etc/` and not tracked here, but together with the bashrc wrapper they form the full defense:

- **Swap**: created `@swap` subvolume on btrfs root, 64 GiB swapfile via `btrfs filesystem mkswapfile` (handles NOCOW + preallocation), `swapon -p 10`. zram remains prio 100. Total swap now 94 GiB (30 zram + 64 disk).
- **sysctl**: `vm.swappiness=150` for aggressive zram use (kernel docs / Pop!_OS recommendation for zram-hybrid setups; priority ordering already protects disk swap from being touched until zram is exhausted).
- **systemd-oomd**: enabled with `SwapUsedLimit=90%`, `DefaultMemoryPressureLimit=60%`, `DefaultMemoryPressureDurationSec=20s`. Monitors both `user-1000.slice` and `user-1000.slice/user@1000.service/claude.slice`.
- **user-1000.slice cap** (drop-in at `/etc/systemd/system/user-.slice.d/50-memory.conf`): `MemoryHigh=50G`, `MemoryMax=56G`, `ManagedOOM*=kill`. Reserves ~6 GiB for system slice.
- **claude.slice cap** (user-level drop-in at `/etc/systemd/user/claude.slice.d/limits.conf`): `MemoryMax=50G`, `MemoryHigh=44G`, `MemorySwapMax=48G`, `ManagedOOM*=kill`. Per-scope cap intentionally omitted — partymasters jest/tsc workers can legitimately need 20+ GiB; oomd kills worst PSI offender instead.
- **OOMScoreAdjust drop-ins**: `systemd-logind` → `-900` (do not kill — owns the seat), `user@.service` → `-100` (protects per-user systemd manager + inherits to descendants).
- **systemd-oomd known bug #33486 mitigation**: `ManagedOOMMemoryPressure=kill` can silently no-op; pair with `ManagedOOMSwap=kill` on every target slice. Both are set.

### Btrfs hygiene

- Installed `snapper`, `snap-pac`, `btrfsmaintenance`, `compsize`, `stress-ng`.
- Created snapper configs for `/` and `/home`. Retention: 0h / 7d / 4w / 3m, NUMBER_LIMIT=20. Enabled `snapper-timeline.timer`, `snapper-cleanup.timer`, `snapper-boot.timer`. `snap-pac` provides pre/post-pacman snapshots automatically.
- Deleted 6 of 8 ad-hoc pre-update snapshots (Feb–Apr 2026); kept the 2 most recent (May 2 + May 13) for rollback safety until snapper accumulates its own.
- `/etc/default/btrfsmaintenance`: `BTRFS_BALANCE_DUSAGE="5 10 30 50"`, `BTRFS_TRIM_PERIOD="weekly"` (was "none"). Enabled `btrfs-balance.timer` (weekly), `btrfs-scrub.timer` (monthly), `btrfs-trim.timer` (weekly). Defrag intentionally off (interferes with snapshot extent sharing).

### Packages: refresh

- Updated `packages-official.txt` and `packages-aur.txt`. New entries beyond today's installs reflect pre-existing drift since the last sync.

---

## 2026-05-17

### Shell: BROWSER env var

- Added `export BROWSER=firefox` to `.bashrc` so Claude Code's `/login` and other URL-opening tools auto-launch Firefox (opens a new tab if Firefox is already running, via Firefox's built-in remoting). Previously `$BROWSER` was unset and xdg-open's fallback chain wasn't picking up Firefox reliably under Hyprland.

### Shell: bashrc Claude prompt-suggestion line reconciled

- Live `.bashrc` had drifted to `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=1` (no comment). Repo had the canonical `=true` with a comment explaining the `sudo -E` env-preservation reason. Updated live to match repo.

### Hyprland: keybinds + pseudotile note

- Removed obsolete `pseudotile = true` option from dwindle block (removed in Hyprland 0.55; `pseudo` is now a per-window state toggled via the `pseudo` dispatcher).
- Changed `$mainMod + J` from `togglesplit` to `layoutmsg, togglesplit` (newer Hyprland dispatcher syntax).
- Added `$mainMod + G` → launch Steam.
- Added fabled10x RGB mode keybinds: `F1` → rest, `F2` → focus, `F3` → build (calls `~/.local/bin/fabled10x`).

### Waybar: style.css cleanup

- Merged two separate `0%` and `100%` keyframe rules into a single `0%, 100% { opacity: 1.0; }` selector. Cosmetic; no behavior change.

---

## 2026-03-31

### Investigation: XDPH Greeter Crash

**Problem:** Login screen crashed — xdg-desktop-portal-hyprland segfaulted during greetd session teardown, greetd reported "greeter exited without creating a session," system shut down.

**Diagnosis:**
- `xdg-desktop-portal-hyprland` (PID 1064, UID 959/greeter) hit SIGSEGV in `wl_proxy_marshal_flags` (`libwayland-client.so.0`)
- Crash happens during `exit()` cleanup — XDPH tries to destroy Wayland proxies after Hyprland compositor is already gone
- Hyprland itself also segfaults in `libaquamarine` DRM disconnect during the same exit path
- Known upstream bug: [hyprwm/xdg-desktop-portal-hyprland#330](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/330) — open, no fix merged
- Crash observed on both Mar 30 and Mar 31 boots

**Trigger sequence:**
1. greetd launches Hyprland greeter → regreet (GTK4) activates XDPH via D-Bus
2. `regreet; hyprctl dispatch exit` fires → Hyprland shuts down
3. XDPH cleanup sends protocol messages to dead compositor → segfault

**Affected versions:**
- xdg-desktop-portal-hyprland 1.3.11-3
- wayland 1.24.0-1
- hyprland 0.54.2-2
- greetd 0.10.3-1, greetd-regreet 0.2.0-1

**Fix (not yet applied):** Add `env = GDK_DEBUG,no-portals` to `/etc/greetd/hyprland.conf` — prevents GTK4/regreet from activating XDPH in the greeter session. Alternative: change exec-once to `regreet; systemctl --user stop xdg-desktop-portal-hyprland; hyprctl dispatch exit`.

**Status:** Researched, fix deferred. Crash is cosmetic in greeter context (happens after session handoff) but can cause login failure when timing is bad.

---

## 2026-03-23

### Streaming & Recording Setup

Full production setup for YouTube recording and livestreaming Claude Code / vibecoding sessions.

**Packages installed:**
- obs-studio, wf-recorder, v4l2loopback-dkms, v4l-utils (official)
- obs-pipewire-audio-capture (AUR)
- noise-suppression-for-voice (RNNoise LADSPA plugin)

**New keybindings (hyprland.conf):**
- SUPER+F9: Stream mode toggle (font size, gaps, notifications, waybar indicator)
- SUPER+F10: Quick screen recording via wf-recorder with NVENC
- Print: Full screenshot to ~/Pictures/Screenshots/
- SUPER+Print: Region screenshot to clipboard

**New scripts (.local/bin/):**
- `stream-toggle.sh` — toggles kitty font 11→14pt, solid background, tighter gaps, pauses dunst, shows waybar indicator
- `quick-record.sh` — toggles wf-recorder with h264_nvenc hardware encoding

**Waybar:**
- Added custom/stream module with LIVE/REC/STREAM indicator (pulsing red/orange/blue pill)
- Added Nerd Font icons to all modules (network, volume, cpu, memory)
- Height 30→34px for video readability

**Kitty:**
- Added `allow_remote_control yes` and `listen_on unix:/tmp/kitty-socket` for stream mode switching
- Added stream.conf documentation file

**Hyprland:**
- border_size 2→3 for video visibility
- OBS window rules: auto workspace 9, projector windows float

**Audio:**
- PipeWire filter chain: RNNoise noise suppression creates "Clean Mic" virtual source for OBS

**Dotfiles:**
- install.sh now symlinks .local/bin/ scripts (step 3/5)
- Updated packages-official.txt (+5) and packages-aur.txt (+1)

### Shell

- Synced .zshrc: `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=1` (live system value)

---

## 2026-03-21

### Shell

- Fixed `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` value from `1` to `true` — Claude Code expects string booleans, not numeric; this broke prompt suggestions silently after an update

---

## 2026-03-11

### Shell

- Added `alias claude='sudo -E /usr/bin/claude'` to bashrc so env vars (prompt suggestions, COLORTERM) pass through sudo

---

## 2026-03-07

### Shell

- Added `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=1` env var to bashrc to enable prompt suggestions in Claude Code (bypasses server-side feature flag)

---

## 2026-03-04

### Packages

- Added: deno, noto-fonts, noto-fonts-cjk, noto-fonts-emoji, noto-fonts-extra, pacman-contrib, ttf-hannom, ttf-indic-otf, ttf-jetbrains-mono-nerd, ttf-khmer, ttf-tibetan-machine, woff2-font-awesome, yt-dlp
- Removed: wlogout-debug

---

## 2026-01-24

### Disable Sleep/Suspend

Sleep is broken on AM5/X870 + nvidia-open (see 2026-01-20 investigation). Disabled all automatic and manual sleep triggers until upstream fixes are available.

**Changes:**
- Commented out suspend listener in `~/.config/hypr/hypridle.conf` (was 15-minute idle trigger)
- Created `/etc/systemd/logind.conf.d/no-suspend.conf` to ignore suspend/hibernate keys

Lock screen (5 min) and DPMS (10 min) still active.

### Fix Slow Shutdown

**Problem:** System hung for ~90 seconds during shutdown before eventually completing.

**Diagnosis:** Journal showed `xdg-document-portal.service` timing out on SIGTERM - systemd waited the full 90-second default timeout before sending SIGKILL. The flatpak document portal had a stuck FUSE mount.

**Fix:** Created systemd drop-in to reduce timeout:
- `/etc/systemd/user/xdg-document-portal.service.d/timeout.conf` with `TimeoutStopSec=10`

### Packages

- Added: flite, pandoc-cli, texlive-basic, texlive-fontsrecommended, texlive-latexrecommended, usbutils
- Added (AUR): zoom

---

## 2026-01-20

### Suspend/Sleep Investigation - Continued Research

**Problem:** System still fails to suspend properly - RGB lights turn off, fans stay running, no keyboard/mouse wake response, requires hard power off.

**System State:**
- BIOS: 1804 (Nov 2025) - latest available, no S3/sleep fixes in changelog
- Kernel: 6.18.5-arch1-1
- Driver: nvidia-open-dkms 590.48.01
- Sleep mode: `mem_sleep_default=deep` applied, `s2idle [deep]` confirmed

**Research Findings:**

1. **nvidia-open is now the correct/recommended driver**
   - Arch Linux switched `nvidia-dkms` to install open modules by default ([Phoronix](https://www.phoronix.com/news/Arch-LInux-NVIDIA-Open-Default))
   - NVIDIA officially recommends open modules for Turing+ GPUs ([NVIDIA Blog](https://developer.nvidia.com/blog/nvidia-transitions-fully-towards-open-source-gpu-kernel-modules/))
   - Performance is identical to proprietary (~1% difference in benchmarks)
   - Blackwell GPUs **require** open modules

2. **Open modules have known power management limitations**
   - Per [GitHub Discussion #457](https://github.com/NVIDIA/open-gpu-kernel-modules/discussions/457): "missing features being addressed (most notably power management)"
   - The `NVreg_EnableGpuFirmware=0` workaround only works with proprietary drivers
   - This is being actively worked on by NVIDIA

3. **AM5/X870 motherboard firmware is the primary suspect**
   - [Level1Techs](https://forum.level1techs.com/t/am5-linux-triggering-suspected-firmware-bug-with-s3-sleep/229940) documents S3 bugs affecting multiple AM5 vendors
   - Manufacturers stopped fixing S3 because Windows uses Modern Standby (S0ix) by default
   - `asus_wmi: failed to register LPS0 sleep handler` confirms board's S0ix is also broken
   - Similar reports on [CachyOS Forum](https://discuss.cachyos.org/t/suspend-to-ram-s3-fails-immediate-wake-or-hang-during-suspend-x870-aorus-elite-wifi-cachyos/14366) for X870 boards

**BIOS Settings to Try:**
- **Sleep State Mode**: Look for "Linux" vs "Windows 10" option (S3 vs Modern Standby)
- **ErP Ready**: Try disabled (can prevent proper S3 power states)
- **Monitoring Software Reboot Workaround**: Enable in AI Tweaker ([ROG Forum](https://rog-forum.asus.com/t5/amd-800-series/rog-strix-x870-f-problems-waking-from-sleep-mode/td-p/1094463))

**Alternative Kernel Parameters to Test:**
```
acpi_sleep=s3_bios,s3_mode
acpi_osi=Linux
acpi.ec_no_wakeup=1
```

**Status:** Investigation complete. Root cause identified as combination of:
1. AM5/X870 motherboard firmware bugs (vendor issue, not fixable by user)
2. nvidia-open power management limitations (being worked on upstream)

No immediate fix available. Options are:
- Wait for NVIDIA open driver power management improvements
- Wait for ASUS BIOS update addressing S3 (unlikely given Modern Standby focus)
- Try proprietary nvidia-dkms + `NVreg_EnableGpuFirmware=0` as workaround (goes against NVIDIA/Arch recommendations)
- Try linux-lts kernel (6.6.x) which may have better suspend support

---

## 2026-01-16

### greetd: Fix "Hyprland started without start-hyprland" warning

**Problem:** Warning displayed on regreet login screen: "Hyprland was started without start-hyprland. This is highly not recommended unless you are in a debugging environment."

**Diagnosis:**
- Warning comes from greeter's Hyprland instance, not user session
- `/etc/greetd/config.toml` was launching Hyprland directly instead of via the recommended `start-hyprland` wrapper
- User session already correctly uses `start-hyprland` via `/usr/share/wayland-sessions/hyprland.desktop`
- dmesg showed previous greeter crashes: `Hyprland[972]: segfault ... in libaquamarine.so`

**Fix applied:**
- Updated `/etc/greetd/config.toml`:
  - Before: `command = "Hyprland -c /etc/greetd/hyprland.conf"`
  - After: `command = "start-hyprland -- -c /etc/greetd/hyprland.conf"`
- The `--` separates start-hyprland args from Hyprland args

**Benefits:** Adds crash recovery and watchdog to greeter (per Hyprland 0.53+ recommendation)

**Status:** Pending verification - logout/reboot required

### greetd: Fix login dialog appearing on wrong monitor

**Problem:** Login dialog (regreet) appears on secondary monitor (DP-1) while video background plays on primary monitor (DP-3). User wants both on primary with secondary blank.

**Diagnosis:**
- ReGreet is a GTK layer-shell app that appears on whatever monitor Hyprland considers "active" at startup
- The greeter's Hyprland config didn't specify which monitor should have initial focus
- Without explicit configuration, Hyprland's default monitor selection was picking DP-1

**Fix applied:**
- Added `cursor { default_monitor = DP-3 }` to `/etc/greetd/hyprland.conf`
- This tells Hyprland to place cursor/focus on DP-3 at startup, making regreet appear there

**Status:** Pending verification - logout/reboot required

**References:**
- [Hyprland Issue #5803](https://github.com/hyprwm/Hyprland/issues/5803) - Feature request for cursor default_monitor
- [ReGreet GitHub](https://github.com/rharish101/ReGreet) - Confirms monitor selection is compositor's responsibility

---

## 2026-01-14

### Migration from SDDM to greetd

**Problem:** SDDM has an architectural flaw causing getty/VT race conditions ([Issue #1844](https://github.com/sddm/sddm/issues/1844)). When SDDM allocates Hyprland to a VT where getty is still "active" according to logind, the session fails to take seat control.

**Solution:** Migrated to greetd with Hyprland as the greeter compositor, preserving video background capability from the timewave2 SDDM theme.

**New stack:**
- **greetd** - Login daemon with proper session/seat handling
- **Hyprland** - Greeter compositor (same as main session)
- **mpvpaper** - Video background player (reusing timewave2 video)
- **ReGreet** - GTK4 login UI with custom CSS theming

**Files created:**
- `/etc/greetd/config.toml` - greetd configuration
- `/etc/greetd/hyprland.conf` - Greeter-specific Hyprland config
- `/etc/greetd/regreet.toml` - ReGreet configuration
- `/etc/greetd/regreet.css` - Timewave2 theme (glassmorphism, green accent)

**Services:**
- Disabled: `sddm`
- Enabled: `greetd`

**Status:** Pending verification - reboot required.

---

### Hyprland Keybinds

- Added `SUPER+K` → launch Kate

---

### SDDM/Hyprland Login Failure - seatd Not Running

**Problem:** After rebooting from Windows 11, SDDM login to Hyprland failed - session crashed within 1 second, dropping to TTY.

**Diagnosis:**
- Hyprland crash report showed: `CBackend::create() failed!`
- Aquamarine (Hyprland's backend) error: `[libseat] Could not connect to socket /run/seatd.sock: No such file or directory`
- libseat tried seatd first (not running), then fell back to logind
- logind backend also failed with: `Could not take control of session: Only owner of session may take control`
- Root cause: `seatd` service was **installed but never enabled** since Jan 10 initial setup
- `aquamarine` package explicitly depends on `seatd` (`libseat.so`)

**Additional finding - VT race condition:**
- On previous boot, SDDM allocated Hyprland to VT 3 → worked
- On this boot, SDDM allocated VT 2 → failed (getty@tty2 conflict)
- This is a known SDDM bug ([Issue #1844](https://github.com/sddm/sddm/issues/1844)) - SDDM queries logind for free VTs but logind doesn't recognize getty sessions as "active"
- The `MinimumVT` setting was removed in SDDM v0.20+, so this can't be configured

**Fix applied:**
1. Enabled seatd service: `systemctl enable --now seatd`
2. Added travis to seat group: `usermod -a -G seat travis`
3. Verified `/run/seatd.sock` created with correct permissions (`root:seat`, `srwxrwx---`)

**Status:** Pending verification - reboot required to test fix.

**Sources:**
- [SDDM VT conflict issue](https://github.com/sddm/sddm/issues/1844)
- [Hyprland libseat discussion](https://github.com/hyprwm/Hyprland/discussions/8421)
- [Arch Wiki - SDDM](https://wiki.archlinux.org/title/SDDM)

---

### Lock Scripts Not Synced to Live System

**Problem:** Lock screen broken again - UI not appearing, mouse disappears, but PIN input works.

**Diagnosis:**
- Previous fixes to `lock.sh` and `lock-with-video.sh` were in dotfiles but never copied to `~/.local/bin/`
- Live scripts still had `DP-6` instead of `DP-3`
- Files were also owned by root:root instead of travis:travis

**Fix applied:**
1. Copied corrected scripts from dotfiles to live system
2. Fixed ownership to travis:travis
3. Added mpvpaper wait loop to `lock.sh` (polls `hyprctl layers` until surface ready)
4. Changed cleanup to `kill -9` for instant video termination on unlock

**Status:** Resolved.

### Hyprlock Monitor Port Fix

**Problem:** Lock screen broken after iGPU disabled - screens don't change visually, mouse disappears, but PIN input still works.

**Diagnosis:**
- When iGPU was disabled (Jan 12), NVIDIA ports changed from DP-4/DP-6 to DP-1/DP-3
- hyprland.conf and swaybg were updated, but hyprlock.conf and lock scripts were missed
- hyprlock was rendering UI to non-existent monitors (DP-4/DP-6)

**Fix applied:**
1. Updated `hyprlock.conf`: DP-4 → DP-1 (secondary), DP-6 → DP-3 (primary)
2. Updated `lock.sh`: MAIN_MONITOR="DP-3"
3. Updated `lock-with-video.sh`: MONITOR="DP-3"

**Status:** Resolved.

### Hyprlock Video Background Fix

**Problem:** After monitor port fix, lock dialog appeared but video background wasn't showing on primary monitor (DP-3). mpvpaper error: "sorry about this but we can't seem to find any output."

**Diagnosis:**
- Manual test worked: `mpvpaper ... & sleep 1 && hyprlock` showed video correctly
- Script failed with "can't find any output" error
- Root cause: **Race condition** - mpvpaper takes time to initialize (connect to Wayland, create EGL context, load video, bind to output). Fixed `sleep 1` wasn't enough time.
- By the time mpvpaper was ready, hyprlock had already locked the session and outputs were unavailable

**Fix applied:**
1. Added wait loop using `hyprctl layers` to check when mpvpaper's surface is created
2. Only proceed to hyprlock after mpvpaper is fully initialized
3. Added 0.5s buffer after surface detection for rendering to stabilize

**Status:** Resolved.

---

## 2026-01-13

### Dolphin Translucency with Kvantum

- Installed Kvantum Qt style engine for true window translucency
- Added `QT_STYLE_OVERRIDE=kvantum` env var to hyprland.conf
- Configured KvGnomeDark theme with:
  - `translucent_windows=true`
  - `transparent_dolphin_view=true`
  - `blurring=true`, `blur_translucent=true`
  - `reduce_window_opacity=10` (90% opacity)
- Added Dolphin opacity windowrule as fallback (0.9 active/inactive)
- Now tracking `.config/Kvantum/` in dotfiles

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

**Status:** Still broken after reboot

**Fix applied (Phase 4 - Missing NVIDIA power management options):**
- Log analysis showed: suspend initiated → NVIDIA prep completed → system hung → hard reboot 3 min later
- Root cause: `/etc/modprobe.d/nvidia.conf` was missing critical power management options
- Original config only had: `options nvidia_drm modeset=1`
- Without `NVreg_PreserveVideoMemoryAllocations=1`, NVIDIA doesn't save VRAM during suspend
- On resume, no VRAM state to restore → black screen with fans running

**Config applied:**
```
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
```
- Rebuilt initramfs with `mkinitcpio -P`

**Additional findings:**
- `asus_wmi: failed to register LPS0 sleep handler` - cosmetic warning, not causing hang
- USB 1-11 (AIO header) timeout errors still present - potential contributing factor
- Kernel 6.18.3 may have suspend regressions (users report 6.17+ issues, LTS works)

**Status:** Pending verification after reboot. If still broken, try:
1. Install `linux-lts` kernel as fallback
2. Disable USB 1-11 wake source: `echo disabled > /sys/bus/usb/devices/usb1/power/wakeup`

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
