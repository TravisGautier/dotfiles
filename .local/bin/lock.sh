#!/bin/bash
# Manual video lockscreen (Super+L).
# Hardened 2026-07-31: hyprlock 0.9.6 can deadlock on exit after unlock,
# which used to orphan the mpvpaper overlay on DP-3 ("stuck screensaver",
# see dotfiles CHANGELOG.md). Cleanup now runs via trap, and a watchdog
# kills hyprlock if the session unlocks (logind LockedHint yes->no) but
# the process never exits.
# Suspend timer removed 2026-07-31: suspend is still broken on this stack —
# RTX 50 s2idle regression on kernel 7.x (open-gpu-kernel-modules #1117),
# AM5/X870 S3 firmware bugs, and a June 2026 attempt died on
# xhci_pci_suspend -110. Do not re-add without also enabling
# nvidia-suspend/resume.service.

VIDEO="/home/travis/.local/share/hypr/lock-video.mp4"
MAIN_MONITOR="DP-3"

SESSION_ID="${XDG_SESSION_ID:-$(loginctl list-sessions --no-legend | awk '$4 == "seat0" {print $1; exit}')}"

cleanup() {
    kill "$MPVPAPER_PID" "$DPMS_PID" "$WATCHDOG_PID" 2>/dev/null
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
