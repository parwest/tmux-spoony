#!/usr/bin/env bash
set -u

selection="$(cat)"
selection="${selection//$'\n'/}"

if [ -z "$selection" ]; then
  tmux display-message "spoony: empty selection"
  exit 0
fi

case "$(uname -s)" in
  Darwin)
    opener="open"
    ;;
  Linux)
    opener="xdg-open"
    ;;
  *)
    tmux display-message "spoony: unsupported OS for open"
    exit 1
    ;;
esac

"$opener" -- "$selection" >/dev/null 2>&1 &
