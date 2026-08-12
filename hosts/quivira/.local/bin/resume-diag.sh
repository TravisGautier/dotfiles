#!/bin/bash
# Run this from TTY after a freeze to capture diagnostics

OUTPUT="/tmp/freeze-diagnostic-$(date +%Y%m%d-%H%M%S).log"

echo "=== Freeze Diagnostic Report ===" > "$OUTPUT"
echo "Captured: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== IDLE EVENTS LOG ===" >> "$OUTPUT"
cat /tmp/idle-events.log 2>/dev/null >> "$OUTPUT" || echo "(no log found)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== HYPRLAND PROCESSES ===" >> "$OUTPUT"
ps aux | grep -E 'hypr|Hypr' | grep -v grep >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== NVIDIA PROCESSES ===" >> "$OUTPUT"
ps aux | grep -i nvidia | grep -v grep >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== DRM CONNECTOR STATUS ===" >> "$OUTPUT"
for f in /sys/class/drm/*/status; do
    echo "$f: $(cat "$f" 2>/dev/null)" >> "$OUTPUT"
done
echo "" >> "$OUTPUT"

echo "=== NVIDIA DRIVER STATE ===" >> "$OUTPUT"
cat /proc/driver/nvidia/version 2>/dev/null >> "$OUTPUT"
cat /proc/driver/nvidia/suspend 2>/dev/null >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== RECENT KERNEL ERRORS ===" >> "$OUTPUT"
journalctl -b -p err --since "15 minutes ago" --no-pager 2>/dev/null >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== HYPRLAND CRASH LOG ===" >> "$OUTPUT"
journalctl --user -u hyprland -b --since "15 minutes ago" --no-pager 2>/dev/null >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== DPMS STATE (if hyprctl works) ===" >> "$OUTPUT"
hyprctl monitors 2>/dev/null >> "$OUTPUT" || echo "(hyprctl not responding)" >> "$OUTPUT"

echo ""
echo "Diagnostic saved to: $OUTPUT"
echo "Review with: cat $OUTPUT"
