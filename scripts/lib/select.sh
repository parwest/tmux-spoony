select_range() {
  local target_pane="$1"
  local original_cursor_x="$2"
  local start="$3"
  local end="$4"
  local lines_down="${5:-0}"
  local delta

  tmux send-keys -t "$target_pane" -X clear-selection

  delta=$((start - original_cursor_x))
  if [ "$delta" -lt 0 ]; then
    move_cursor "$target_pane" cursor-left "$((-delta))"
  elif [ "$delta" -gt 0 ]; then
    move_cursor "$target_pane" cursor-right "$delta"
  fi

  tmux send-keys -t "$target_pane" -X begin-selection
  if [ "$lines_down" -gt 0 ]; then
    tmux send-keys -t "$target_pane" -X start-of-line
    move_cursor "$target_pane" cursor-down "$lines_down"
    move_cursor "$target_pane" cursor-right "$end"
  else
    delta=$((end - start))
    if [ "$delta" -lt 0 ]; then
      move_cursor "$target_pane" cursor-left "$((-delta))"
    elif [ "$delta" -gt 0 ]; then
      move_cursor "$target_pane" cursor-right "$delta"
    fi
  fi
}

select_on_line_offset() {
  local target_pane="$1"
  local line_offset="$2"
  local start="$3"
  local end="$4"

  tmux send-keys -t "$target_pane" -X clear-selection

  if [ "$line_offset" -gt 0 ]; then
    move_cursor "$target_pane" cursor-down "$line_offset"
  elif [ "$line_offset" -lt 0 ]; then
    move_cursor "$target_pane" cursor-up "$((-line_offset))"
  fi

  tmux send-keys -t "$target_pane" -X start-of-line
  move_cursor "$target_pane" cursor-right "$start"
  tmux send-keys -t "$target_pane" -X begin-selection
  move_cursor "$target_pane" cursor-right "$((end - start))"
}
