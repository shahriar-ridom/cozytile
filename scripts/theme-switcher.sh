#!/usr/bin/env bash
# theme-switcher.sh [next|everforest|sakura|wallpaper]  - talk to the running shell.
set -u
case "${1:-next}" in
  next) exec qs -c cozytile ipc call theme next ;;
  *)    exec qs -c cozytile ipc call theme set "$1" ;;
esac
