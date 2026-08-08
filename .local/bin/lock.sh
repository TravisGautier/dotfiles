#!/bin/bash
# Manual video lockscreen (Super+L).
# Reworked 2026-08-08: hyprlock 0.9.6 can deadlock on exit after unlock
# (hyprlock#791), which used to orphan the mpvpaper overlay on DP-3
# ("stuck screensaver") and stack duplicate lock instances. Two defenses:
#   1. Single-instance guard below — never stack a second hyprlock.
#   2. hypridle's on_unlock_cmd runs unlock-cleanup.sh (compositor-driven
#      via hyprland-lock-notify-v1) to reap a deadlocked hyprlock and any
#      leftover mpvpaper within seconds of a real unlock.
# The old logind LockedHint watchdog was removed: hyprlock never sets
# LockedHint, so it could never fire. Manual fallback stays on
# Super+Shift+L (unstick-lockscreen.sh).
# Suspend timer removed 2026-07-31: suspend is still broken on this stack —
# RTX 50 s2idle regression on kernel 7.x (open-gpu-kernel-modules #1117),
# AM5/X870 S3 firmware bugs, and a June 2026 attempt died on
# xhci_pci_suspend -110. Do not re-add without also enabling
# nvidia-suspend/resume.service.

VIDEO="/home/travis/.local/share/hypr/lock-video.mp4"
MAIN_MONITOR="DP-3"
STATE=/tmp/hypr-lock-state
LOG=/home/travis/.local/bin/idle-log.sh

if pgrep -x hyprlock >/dev/null; then
    if [ "$(cat "$STATE" 2>/dev/null)" = "locked" ]; then
        "$LOG" "LOCK_SKIP_ALREADY_LOCKED"
        exit 0
    fi
    "$LOG" "LOCK_REAP_STALE"
    pkill -9 -x hyprlock
    pkill -f 'mpvpaper.*lock-video'
    sleep 0.5
fi

cleanup() {
    kill "$MPVPAPER_PID" "$DPMS_PID" 2>/dev/null
    hyprctl dispatch dpms on
}
trap cleanup EXIT

# Start video background
mpvpaper -vs -o "no-audio loop" --layer overlay "$MAIN_MONITOR" "$VIDEO" &
MPVPAPER_PID=$!

# Wait for mpvpaper to create its layer (max 2 seconds)
for i in {1..20}; do
    if hyprctl layers | grep -q "mpvpaper"; then
        sleep 0.1  # Brief buffer for rendering to stabilize
        break
    fi
    sleep 0.1
done

# Timeout: screens off after 60 seconds
(sleep 60 && hyprctl dispatch dpms off) &
DPMS_PID=$!

hyprlock &
HYPRLOCK_PID=$!

# Blocks until unlock (or until unlock-cleanup.sh reaps a hung hyprlock)
wait "$HYPRLOCK_PID"
