#!/usr/bin/env bash

# Quick conference call workspace setup for niri
# Sets current window to 70%, opens Google Calendar in Brave at 30% next to it

set -e

# Check if there's a focused window
CURRENT_WINDOW=$(niri msg -j focused-window 2>/dev/null)

if [ -z "$CURRENT_WINDOW" ] || [ "$CURRENT_WINDOW" = "null" ]; then
  notify-send "Meeting Setup" "No window focused, opening calendar only"
  brave --new-window "https://calendar.google.com" &
  exit 0
fi

# Set current window to 68% width (accounting for gaps)
niri msg action set-column-width "68%"

# Open Brave with Google Calendar (will open as new column to the right)
brave --new-window "https://calendar.google.com" &

# Wait for Brave to open and become the focused window
sleep 1.5

# Set Brave window to 30% width (68% + 30% = 98%, leaving room for gap)
niri msg action set-column-width "30%"

# Focus back on the original window (left column)
niri msg action focus-column-left

# Send notification
notify-send "Meeting Setup" "Ready for conference call (70/30 split)"
