#!/bin/bash
# Panic button (Super+Shift+L): clear a stuck lockscreen/screensaver
# without rebooting. Kills the orphaned mpvpaper lock-video overlay and
# any hung hyprlock, then makes sure the screens are on.
# See dotfiles CHANGELOG.md 2026-07-31.
pkill -x mpvpaper
pkill -9 -x hyprlock
hyprctl dispatch dpms on
