#!/bin/bash

# Check if the terminal is already running
if ! pgrep -f "gemini-scratchpad" >/dev/null; then
  # Force Alacritty to use Zsh, load your .zshrc, and run the CLI. If it fails, keep Zsh open!
  hyprctl dispatch exec "[workspace special:gemini] alacritty --class gemini-scratchpad -e zsh -c 'source ~/.zshrc && gemini || zsh'"
  sleep 0.5
fi

# Toggle the workspace
hyprctl dispatch togglespecialworkspace gemini
