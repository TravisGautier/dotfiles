#!/usr/bin/env bash
# Stream Mode Toggle
# Switches between normal desktop and a clean, readable stream layout.
# Bind to SUPER+F9 in Hyprland.

STATE_FILE="/tmp/stream-mode-active"
KITTY_SOCKET="unix:/tmp/kitty-socket"

activate() {
    touch "$STATE_FILE"

    # Kitty: larger font, solid background
    kitty @ --to "$KITTY_SOCKET" set-font-size 14 2>/dev/null
    kitty @ --to "$KITTY_SOCKET" set-background-opacity 1.0 2>/dev/null

    # Hyprland: tighter gaps for cleaner look
    hyprctl keyword general:gaps_out 10
    hyprctl keyword general:gaps_in 3
    hyprctl keyword general:border_size 3

    # Silence notifications
    dunstctl set-paused true 2>/dev/null

    # Refresh waybar to show stream indicator
    pkill -SIGRTMIN+1 waybar

    notify-send -u low -t 3000 "Stream Mode" "ON — fonts up, gaps tight, notifications paused"
}

deactivate() {
    rm -f "$STATE_FILE"

    # Kitty: restore normal settings
    kitty @ --to "$KITTY_SOCKET" set-font-size 11 2>/dev/null
    kitty @ --to "$KITTY_SOCKET" set-background-opacity 0.9 2>/dev/null

    # Hyprland: restore normal gaps
    hyprctl keyword general:gaps_out 20
    hyprctl keyword general:gaps_in 5
    hyprctl keyword general:border_size 2

    # Re-enable notifications
    dunstctl set-paused false 2>/dev/null

    # Refresh waybar
    pkill -SIGRTMIN+1 waybar

    notify-send -u low -t 3000 "Stream Mode" "OFF — back to normal"
}

if [ -f "$STATE_FILE" ]; then
    deactivate
else
    activate
fi
