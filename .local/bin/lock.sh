#!/bin/bash
VIDEO="/home/travis/.local/share/hypr/lock-video.mp4"
MAIN_MONITOR="DP-6"

# Start video background
mpvpaper -vs -o "no-audio loop" --layer overlay "$MAIN_MONITOR" "$VIDEO" &
MPVPAPER_PID=$!

# Timeout: screens off after 60 seconds
(sleep 60 && hyprctl dispatch dpms off) &
DPMS_PID=$!

# Timeout: suspend after 10 minutes
(sleep 600 && systemctl suspend) &
SUSPEND_PID=$!

# Run hyprlock (blocks until unlock)
hyprlock

# Cleanup on unlock
kill $MPVPAPER_PID $DPMS_PID $SUSPEND_PID 2>/dev/null
hyprctl dispatch dpms on
