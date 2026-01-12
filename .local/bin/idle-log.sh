#!/bin/bash
# Idle event logger for debugging hypridle freeze issues
LOG="/tmp/idle-events.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG"
