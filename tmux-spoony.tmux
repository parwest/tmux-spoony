#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

url_key="$(tmux show-option -gqv @spoony-url-key)"
path_key="$(tmux show-option -gqv @spoony-path-key)"
command_key="$(tmux show-option -gqv @spoony-command-key)"
line_key="$(tmux show-option -gqv @spoony-line-key)"
open_key="$(tmux show-option -gqv @spoony-open-key)"

if [ -z "$url_key" ]; then
  url_key="u"
fi

if [ -z "$path_key" ]; then
  path_key="p"
fi

if [ -z "$command_key" ]; then
  command_key="m"
fi

if [ -z "$line_key" ]; then
  line_key="x"
fi

if [ -z "$open_key" ]; then
  open_key="o"
fi

bind_copy_mode_key() {
  key="$1"
  shift

  if [ -n "$key" ] && [ "$key" != "off" ]; then
    tmux bind-key -T copy-mode-vi "$key" "$@"
  fi
}

bind_copy_mode_key "$url_key" run-shell "bash '$CURRENT_DIR/scripts/select-on-line.sh' url '#{pane_id}'"
bind_copy_mode_key "$path_key" run-shell "bash '$CURRENT_DIR/scripts/select-on-line.sh' path '#{pane_id}'"
bind_copy_mode_key "$command_key" run-shell "bash '$CURRENT_DIR/scripts/select-on-line.sh' command '#{pane_id}'"
bind_copy_mode_key "$line_key" send-keys -X select-line
bind_copy_mode_key "$open_key" send-keys -X copy-pipe-and-cancel "bash '$CURRENT_DIR/scripts/open-selection.sh' '#{pane_id}'"
