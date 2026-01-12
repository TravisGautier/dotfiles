#!/bin/bash
VIDEO="/home/travis/.local/share/hypr/lock-video.mp4"
MONITOR="DP-6"

# Start video wallpaper (overlay layer - shows through hyprlock transparency)
mpvpaper --layer overlay -o "no-audio --loop" "$MONITOR" "$VIDEO" &
MPVPAPER_PID=$!

# Brief delay to let mpvpaper initialize
sleep 0.3

# Run hyprlock (blocks until unlock)
hyprlock

# Cleanup after unlock
kill $MPVPAPER_PID 2>/dev/null
