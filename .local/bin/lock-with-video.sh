#!/bin/bash
# Video lockscreen (hypridle idle path).
# Hardened 2026-07-31: hyprlock 0.9.6 can deadlock on exit after unlock,
# which used to orphan the mpvpaper overlay on DP-3 ("stuck screensaver",
# see dotfiles CHANGELOG.md). Cleanup now runs via trap, and a watchdog
# kills hyprlock if the session unlocks (logind LockedHint yes->no) but
# the process never exits.

VIDEO="/home/travis/.local/share/hypr/lock-video.mp4"
MONITOR="DP-3"

SESSION_ID="${XDG_SESSION_ID:-$(loginctl list-sessions --no-legend | awk '$4 == "seat0" {print $1; exit}')}"

cleanup() {
    kill "$MPVPAPER_PID" "$WATCHDOG_PID" 2>/dev/null
}
trap cleanup EXIT

# Start video wallpaper (overlay layer - shows through hyprlock transparency)
mpvpaper --layer overlay -o "no-audio --loop" "$MONITOR" "$VIDEO" &
MPVPAPER_PID=$!

# Brief delay to let mpvpaper initialize
sleep 0.3

hyprlock &
HYPRLOCK_PID=$!

# Watchdog: fail-safe — only fires after LockedHint has been observed "yes"
# and then flips to "no" while hyprlock is still alive 5s later.
(
    seen_locked=0
    while kill -0 "$HYPRLOCK_PID" 2>/dev/null; do
        hint=$(loginctl show-session "$SESSION_ID" -p LockedHint --value 2>/dev/null)
        if [ "$hint" = "yes" ]; then
            seen_locked=1
        elif [ "$hint" = "no" ] && [ "$seen_locked" -eq 1 ]; then
            sleep 5
            kill -0 "$HYPRLOCK_PID" 2>/dev/null && kill -9 "$HYPRLOCK_PID" 2>/dev/null
            exit 0
        fi
        sleep 2
    done
) &
WATCHDOG_PID=$!

# Blocks until unlock (or until the watchdog reaps a hung hyprlock)
wait "$HYPRLOCK_PID"
