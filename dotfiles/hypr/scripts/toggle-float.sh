#!/bin/bash

# Check if the currently active window is already floating
is_floating=$(hyprctl activewindow -j | grep '"floating": true')

if [ -n "$is_floating" ]; then
  # If it's floating, just snap it back to tiling
  hyprctl dispatch togglefloating
else
  # If it's tiled, float it, resize it perfectly, and center it
  hyprctl dispatch togglefloating
  hyprctl dispatch resizeactive exact 900 700
  hyprctl dispatch centerwindow
fi
