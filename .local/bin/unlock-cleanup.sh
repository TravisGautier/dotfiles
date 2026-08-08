#!/bin/bash
# Event-driven reaper for the hyprlock 0.9.6 exit deadlock (hyprlock#791).
# Wired to hypridle's on_unlock_cmd, which fires via hyprland-lock-notify-v1
# the moment the compositor releases the session lock — so unlike the old
# logind LockedHint watchdog (removed 2026-08-08; hyprlock never sets that
# hint), this always runs on a real unlock.
#
# hyprlock sometimes deadlocks in a futex after a successful unlock, which
# orphans the mpvpaper lock-video overlay on DP-3 ("stuck screensaver").
# Give it a grace period to exit cleanly, then SIGKILL; the lock scripts'
# EXIT traps reap their own mpvpaper, and we sweep any stragglers.

LOG=/home/travis/.local/bin/idle-log.sh
STATE=/tmp/hypr-lock-state

"$LOG" "UNLOCK_CLEANUP_START"
echo unlocked > "$STATE"

sleep 3

reaped_hyprlock=0
if pgrep -x hyprlock >/dev/null; then
    reaped_hyprlock=$(pgrep -cx hyprlock)
    pkill -9 -x hyprlock
    sleep 1
fi

reaped_mpv=0
if pgrep -f 'mpvpaper.*lock-video' >/dev/null; then
    reaped_mpv=$(pgrep -cf 'mpvpaper.*lock-video')
    pkill -f 'mpvpaper.*lock-video'
fi

hyprctl dispatch dpms on >/dev/null 2>&1

"$LOG" "UNLOCK_CLEANUP_DONE hyprlock=$reaped_hyprlock mpvpaper=$reaped_mpv"
