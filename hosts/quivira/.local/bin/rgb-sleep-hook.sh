#!/bin/bash
case "$1" in
  pre)
    # Turn off all 4 RAM sticks before sleep
    /usr/bin/openrgb --noautoconnect -d 0 -m direct -c 000000 2>/dev/null
    /usr/bin/openrgb --noautoconnect -d 1 -m direct -c 000000 2>/dev/null
    /usr/bin/openrgb --noautoconnect -d 2 -m direct -c 000000 2>/dev/null
    /usr/bin/openrgb --noautoconnect -d 3 -m direct -c 000000 2>/dev/null
    ;;
  post)
    # Optional: restore RGB after wake (uncomment to enable)
    # /usr/bin/openrgb --profile default
    ;;
esac
