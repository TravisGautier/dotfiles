#!/bin/bash
# Video lockscreen (hypridle idle path).
# Reworked 2026-08-08: hyprlock 0.9.6 can deadlock on exit after unlock
# (hyprlock#791), which used to orphan the mpvpaper overlay on DP-3
# ("stuck screensaver") and stack duplicate lock instances when hypridle
# re-fired. Two defenses now:
#   1. Single-instance guard below — never stack a second hyprlock.
#   2. hypridle's on_unlock_cmd runs unlock-cleanup.sh (compositor-driven
#      via hyprland-lock-notify-v1) to reap a deadlocked hyprlock and any
#      leftover mpvpaper within seconds of a real unlock.
# The old logind LockedHint watchdog was removed: hyprlock never sets
# LockedHint, so it could never fire. Manual fallback stays on
# Super+Shift+L (unstick-lockscreen.sh).

VIDEO="/home/travis/.local/share/hypr/lock-video.mp4"
MONITOR="DP-3"
STATE=/tmp/hypr-lock-state
LOG=/home/travis/.local/bin/idle-log.sh

if pgrep -x hyprlock >/dev/null; then
    if [ "$(cat "$STATE" 2>/dev/null)" = "locked" ]; then
        # Session is genuinely locked already; hypridle just re-fired
        # after activity at the lock screen. Nothing to do.
        "$LOG" "LOCK_SKIP_ALREADY_LOCKED"
        exit 0
    fi
    # hyprlock alive but session not locked: a deadlocked zombie the
    # unlock reaper missed (e.g. hypridle was restarted). Clear it.
    "$LOG" "LOCK_REAP_STALE"
    pkill -9 -x hyprlock
    pkill -f 'mpvpaper.*lock-video'
    sleep 0.5
fi

cleanup() {
    kill "$MPVPAPER_PID" 2>/dev/null
}
trap cleanup EXIT

# Start video wallpaper (overlay layer - shows through hyprlock transparency)
mpvpaper --layer overlay -o "no-audio loop" "$MONITOR" "$VIDEO" &
MPVPAPER_PID=$!

# Brief delay to let mpvpaper initialize
sleep 0.3

hyprlock &
HYPRLOCK_PID=$!

# Blocks until unlock (or until unlock-cleanup.sh reaps a hung hyprlock)
wait "$HYPRLOCK_PID"
