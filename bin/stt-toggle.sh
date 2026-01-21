#!/usr/bin/env bash
# stt-toggle.sh - Toggle waystt with Rofi visual feedback
# Usage: stt-toggle.sh [type|clipboard]
#   type (default) - Types transcribed text directly via ydotool
#   clipboard - Copies transcribed text to clipboard via wl-copy

set -euo pipefail

# ydotool socket location (NixOS default)
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/run/user/$(id -u)/.ydotool_socket}"

LOCK_FILE="/tmp/waystt-recording"
ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/stt.rasi"
MODE="${1:-type}"

start_recording() {
    touch "$LOCK_FILE"

    # Start waystt in background, piping to chosen output
    case "$MODE" in
        type)
            waystt --pipe-to ydotool type --file - &
            ;;
        clipboard)
            waystt --pipe-to wl-copy &
            ;;
    esac

    WAYSTT_PID=$!

    # Show Rofi popup - pressing Enter or Escape will stop recording
    echo -e "Stop Recording\nCancel" | rofi -dmenu \
        -p "Recording" \
        -theme "$ROFI_THEME" \
        -selected-row 0 \
        -kb-accept-entry "Return" \
        -kb-cancel "Escape" 2>/dev/null || true

    # Send transcribe signal to waystt
    pkill --signal SIGUSR1 waystt 2>/dev/null || true

    rm -f "$LOCK_FILE"

    # Notify completion
    notify-send -t 2000 "STT" "Transcription complete"
}

stop_recording() {
    pkill --signal SIGUSR1 waystt 2>/dev/null || true
    rm -f "$LOCK_FILE"
}

# Main: toggle recording state
if pgrep -x waystt > /dev/null; then
    stop_recording
else
    start_recording
fi
