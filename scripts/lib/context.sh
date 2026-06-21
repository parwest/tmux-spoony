visible_cursor_line() {
  local target_pane="$1"
  local cursor_row="$2"

  if [ -z "$cursor_row" ]; then
    return
  fi

  cursor_row=$((cursor_row - scroll_pos))

  tmux capture-pane -p -t "$target_pane" -S "$cursor_row" -E "$cursor_row" 2>/dev/null |
    sed -n '1p'
}

load_copy_context() {
  cursor_x="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_x}')"
  cursor_y="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_y}')"
  line="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_line}')"
  scroll_pos="$(tmux display-message -p -t "$pane_id" '#{scroll_position}')"

  if ! is_unsigned_int "$scroll_pos"; then
    scroll_pos=0
  fi

  if [ -z "$line" ]; then
    show_message "no copy-mode line found"
    exit 0
  fi

  if ! is_unsigned_int "$cursor_x"; then
    cursor_x=0
  fi

  if ! is_unsigned_int "$cursor_y"; then
    cursor_y=""
  fi

  if [ -n "$cursor_y" ]; then
    local visible
    visible="$(visible_cursor_line "$pane_id" "$cursor_y")"
    if [ -n "$visible" ]; then
      line="$visible"
      if [ "$cursor_x" -gt "${#line}" ]; then
        cursor_x="${#line}"
      fi
    fi
  fi
}

load_joined_url_context() {
  local regex="$1"
  local current_line="$line"
  local original_cursor_x="$cursor_x"
  local start end joined needle trimmed idx line_len prefix pane_width wrap_adjust

  if [ -z "$cursor_y" ] || [ -z "$current_line" ]; then
    return
  fi

  # capture a 40-line window around the cursor so wrapped urls can be rejoined.
  start=$((cursor_y - scroll_pos - 40))
  end=$((cursor_y - scroll_pos + 40))

  trimmed="$(printf '%s' "$current_line" | sed 's/[[:space:]]*$//')"
  if [ -z "$trimmed" ]; then
    return
  fi

  pane_width="$(tmux display-message -p -t "$pane_id" '#{pane_width}' 2>/dev/null)"

  while IFS= read -r joined; do
    [[ "$joined" =~ $regex ]] || continue

    idx=-1
    for needle in "$current_line" "$trimmed"; do
      [ -z "$needle" ] && continue
      if [[ "$joined" == *"$needle"* ]]; then
        prefix="${joined%%"$needle"*}"
        idx="${#prefix}"
        break
      fi
    done

    if [ "$idx" -ge 0 ]; then
      line="$joined"

      # add a wrap adjustment when the match crosses soft wraps.
      wrap_adjust=0
      if is_unsigned_int "$pane_width" && [ "$pane_width" -gt 0 ] && [ "$idx" -ge "$pane_width" ]; then
        wrap_adjust=$((idx / pane_width))
      fi

      cursor_x=$((idx + original_cursor_x))
      line_len="${#line}"
      if [ "$cursor_x" -gt "$line_len" ]; then
        cursor_x="$line_len"
      fi
      cursor_x=$((cursor_x + wrap_adjust))
      return
    fi
  done < <(tmux capture-pane -p -J -t "$pane_id" -S "$start" -E "$end" 2>/dev/null)
}
