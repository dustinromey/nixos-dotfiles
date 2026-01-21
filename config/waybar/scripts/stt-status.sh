#!/usr/bin/env bash
# stt-status.sh - Waybar module for waystt status

if pgrep -x waystt > /dev/null; then
    # Check if actively recording
    if [ -f /tmp/waystt-recording ]; then
        echo '{"text": "", "class": "recording", "tooltip": "Recording... (click to stop)"}'
    else
        echo '{"text": "", "class": "ready", "tooltip": "STT ready"}'
    fi
else
    echo '{"text": "", "class": "inactive", "tooltip": "Click to start recording"}'
fi
