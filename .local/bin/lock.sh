#!/bin/bash
VIDEO="/home/travis/.local/share/hypr/lock-video.mp4"
MAIN_MONITOR="DP-3"

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

# Timeout: suspend after 10 minutes
(sleep 600 && systemctl suspend) &
SUSPEND_PID=$!

# Run hyprlock (blocks until unlock)
hyprlock

# Cleanup on unlock (SIGKILL for instant termination)
kill -9 $MPVPAPER_PID $DPMS_PID $SUSPEND_PID 2>/dev/null
hyprctl dispatch dpms on
