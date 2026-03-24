#!/usr/bin/env bash
# Quick Record Toggle (wf-recorder)
# Toggle start/stop screen recording with hardware encoding.
# Bind to SUPER+F10 in Hyprland.

PIDFILE="/tmp/quick-record.pid"
OUTDIR="$HOME/Videos/Recordings"

stop_recording() {
    kill -SIGINT "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    notify-send -u low -t 3000 "Recording" "Saved to $OUTDIR"
}

start_recording() {
    mkdir -p "$OUTDIR"
    FILENAME="$OUTDIR/$(date +%Y-%m-%d_%H-%M-%S).mp4"

    # Use NVENC hardware encoding on NVIDIA GPU
    wf-recorder \
        -c h264_nvenc \
        -p preset=p4 \
        -p tune=hq \
        -p rc=constqp \
        -p qp=23 \
        --audio \
        -f "$FILENAME" &

    echo $! > "$PIDFILE"
    notify-send -u low -t 3000 "Recording" "Started — $FILENAME"
}

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    stop_recording
else
    rm -f "$PIDFILE"
    start_recording
fi
