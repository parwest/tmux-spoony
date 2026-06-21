select_url() {
  local url_regex pane_width

  label="URL"
  url_regex='(https?|ftp)://[^[:space:]<>"'\'']+'

  load_joined_url_context "$url_regex"
  read -r best_start best_end < <(find_match "$url_regex" "$mode" "$line" "$cursor_x" "url")

  pane_width="$(tmux display-message -p -t "$pane_id" '#{pane_width}' 2>/dev/null)"
  if is_unsigned_int "$pane_width" && [ "$pane_width" -gt 0 ] && [ "$best_start" -ge 0 ]; then
    best_end=$((best_end + best_end / pane_width - best_start / pane_width))
  fi
}

select_path() {
  local visible_line

  label="path"
  visible_line="$(visible_cursor_line "$pane_id" "$cursor_y")"
  if [ -n "$visible_line" ]; then
    line="$visible_line"
    if [ "$cursor_x" -gt "${#line}" ]; then
      cursor_x="${#line}"
    fi
  fi

  read -r best_start best_end < <(find_match '(~|/|\./|\.\./|[[:alnum:]_.-]+/)[^[:space:]<>"'\'']+' "$mode" "$line" "$cursor_x" "path")
}

sha_wrap_pending_get() {
  tmux show-option -p -t "$pane_id" -qv @spoony-sha-wrap-pending
}

sha_wrap_pending_set() {
  tmux set-option -p -t "$pane_id" @spoony-sha-wrap-pending 1
  tmux set-option -p -t "$pane_id" @spoony-sha-wrap-pending-row "$1"
}

sha_wrap_pending_row_get() {
  tmux show-option -p -t "$pane_id" -qv @spoony-sha-wrap-pending-row
}

sha_wrap_pending_clear() {
  tmux set-option -p -t "$pane_id" -u @spoony-sha-wrap-pending 2>/dev/null
  tmux set-option -p -t "$pane_id" -u @spoony-sha-wrap-pending-row 2>/dev/null
}

sha_press_clock_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local secs="${EPOCHREALTIME%%[.,]*}" frac="${EPOCHREALTIME#*[.,]}"
    frac="${frac}000"
    printf '%s' "$((secs * 1000 + 10#${frac:0:3}))"
    return
  fi

  local ns
  ns="$(date +%s%N 2>/dev/null)"
  if [[ "$ns" =~ ^[0-9]+$ ]] && [ "${#ns}" -ge 13 ]; then
    printf '%s' "$((ns / 1000000))"
    return
  fi

  if command -v perl >/dev/null 2>&1; then
    local pms
    pms="$(perl -MTime::HiRes=time -e 'printf("%d", time() * 1000)' 2>/dev/null)"
    if [[ "$pms" =~ ^[0-9]+$ ]]; then
      printf '%s' "$pms"
      return
    fi
  fi

  printf '%s' "$(($(date +%s) * 1000))"
}

sha_last_press_get() {
  tmux show-option -p -t "$pane_id" -qv @spoony-sha-last-press-ms
}

sha_last_press_set() {
  tmux set-option -p -t "$pane_id" @spoony-sha-last-press-ms "$1"
}

sha_lock_dir=""

sha_lock_path() {
  printf '%s/spoony-sha-%s.lock' "${TMPDIR:-/tmp}" "${pane_id//[^A-Za-z0-9]/_}"
}

sha_lock_acquire() {
  local dir owner
  dir="$(sha_lock_path)"

  if mkdir "$dir" 2>/dev/null; then
    sha_lock_dir="$dir"
    printf '%s' "$$" >"$dir/pid" 2>/dev/null
    return 0
  fi

  owner="$(cat "$dir/pid" 2>/dev/null)"
  if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
    rm -rf "$dir" 2>/dev/null
    if mkdir "$dir" 2>/dev/null; then
      sha_lock_dir="$dir"
      printf '%s' "$$" >"$dir/pid" 2>/dev/null
      return 0
    fi
  fi

  return 1
}

sha_lock_release() {
  if [ -n "$sha_lock_dir" ]; then
    rm -rf "$sha_lock_dir" 2>/dev/null
    sha_lock_dir=""
  fi
}

# remember when the downward scan hits the end so the next press can wrap.
select_sha_wrap() {
  local regex="$1"
  local prompt_regex="$2"
  local current_row="$3"
  local row row_index prompt_index=-1 target_index=-1 s e
  local -a rows=()

  while IFS= read -r row; do
    rows+=("$row")
  done < <(tmux capture-pane -p -t "$pane_id" -S - -E "$current_row" 2>/dev/null)

  if [ "${#rows[@]}" -eq 0 ]; then
    return 1
  fi

  for row_index in "${!rows[@]}"; do
    if [[ "${rows[$row_index]}" =~ $prompt_regex ]]; then
      prompt_index="$row_index"
    fi
  done

  if [ "$prompt_index" -lt 0 ]; then
    return 1
  fi

  for ((row_index = prompt_index + 1; row_index < ${#rows[@]}; row_index++)); do
    read -r s e < <(find_match "$regex" "nearest" "${rows[$row_index]}" 0 "sha")
    if [ "$s" -ge 0 ] && [ "$e" -ge "$s" ]; then
      best_start="$s"
      best_end="$e"
      target_index="$row_index"
      break
    fi
  done

  if [ "$target_index" -lt 0 ]; then
    return 1
  fi

  end_lines_down=$((target_index - (${#rows[@]} - 1)))
  return 0
}

# the first end-of-list scan only sets the wrap hint.
select_sha_down() {
  local regex="$1"
  local prompt_regex="$2"
  local current_row start_row row row_index found_index s e
  local wrap_pending wrap_pending_row now last gap
  local repeat_ms=120

  if ! sha_lock_acquire; then
    exit 0
  fi
  trap sha_lock_release EXIT

  if [ -z "$cursor_y" ]; then
    show_message "no cursor position for downward scan"
    exit 0
  fi

  current_row=$((cursor_y - scroll_pos))
  start_row=$((cursor_y - scroll_pos))

  now="$(sha_press_clock_ms)"
  last="$(sha_last_press_get)"
  if [[ "$last" =~ ^[0-9]+$ ]]; then
    gap=$((now - last))
  else
    gap="$repeat_ms"
  fi
  sha_last_press_set "$now"

  wrap_pending="$(sha_wrap_pending_get)"
  if [ "$wrap_pending" = "1" ]; then
    wrap_pending_row="$(sha_wrap_pending_row_get)"
    if [ "$wrap_pending_row" = "$current_row" ]; then
      if [ "$gap" -lt "$repeat_ms" ]; then
        exit 0
      fi

      sha_wrap_pending_clear
      if select_sha_wrap "$regex" "$prompt_regex" "$current_row"; then
        return 0
      fi

      show_message "no git SHA after prompt"
      exit 0
    fi

    sha_wrap_pending_clear
  fi

  row_index=0
  found_index=-1

  while IFS= read -r row; do
    if [ "$row_index" -ge 1 ]; then
      read -r s e < <(find_match "$regex" "nearest" "$row" 0 "sha")
      if [ "$s" -ge 0 ] && [ "$e" -ge "$s" ]; then
        best_start="$s"
        best_end="$e"
        found_index="$row_index"
        break
      fi
    fi
    row_index=$((row_index + 1))
  done < <(tmux capture-pane -p -t "$pane_id" -S "$start_row" 2>/dev/null)

  if [ "$found_index" -lt 1 ]; then
    local next_key
    next_key="$(tmux show-option -gqv @spoony-active-sha-next-key)"
    if [ -z "$next_key" ] || [ "$next_key" = "off" ]; then
      next_key="S"
    fi
    sha_wrap_pending_set "$current_row"
    show_message "git SHA end; press $next_key again to wrap"
    exit 0
  fi

  sha_wrap_pending_clear
  end_lines_down="$found_index"
}

select_sha() {
  local sha_regex
  local prompt_regex

  label="git SHA"
  sha_regex='[0-9a-f]{7,64}'
  prompt_regex="$(command_prompt_regex)"

  if [ "$mode" != "down" ]; then
    sha_wrap_pending_clear
  fi

  if [ "$mode" = "down" ]; then
    select_sha_down "$sha_regex" "$prompt_regex"
    return
  fi

  read -r best_start best_end < <(find_match "$sha_regex" "$mode" "$line" "$cursor_x" "sha")
}

# stop at the next prompt, or fall back to the last non-empty row.
extend_command_selection_to_block() {
  local prompt_regex="$1"
  local block_end=0
  local end_row="$line"
  local row_index=0
  local row

  if [ "$mode" != "block" ] || [ -z "$cursor_y" ]; then
    return
  fi

  while IFS= read -r row; do
    if [ "$row_index" -gt 0 ] && { [[ "$row" =~ $prompt_regex ]] || [[ "$row " =~ $prompt_regex ]]; }; then
      break
    fi
    if [[ "$row" =~ [^[:space:]] ]]; then
      block_end="$row_index"
      end_row="$row"
    fi
    row_index=$((row_index + 1))
  done < <(tmux capture-pane -p -t "$pane_id" -S "$((cursor_y - scroll_pos))" 2>/dev/null)

  if [ "$block_end" -gt 0 ]; then
    best_end=$((${#end_row} - 1))
    while [ "$best_end" -ge 0 ] && [ "${end_row:$best_end:1}" = " " ]; do
      best_end=$((best_end - 1))
    done
    end_lines_down="$block_end"
  fi
}

select_command() {
  local prompt_regex

  label="command"
  prompt_regex="$(command_prompt_regex)"

  if ! [[ "$line" =~ $prompt_regex ]]; then
    show_message "no command prompt on cursor line"
    exit 0
  fi

  local prompt_prefix="${line%%"${BASH_REMATCH[0]}"*}"
  best_start=$((${#prompt_prefix} + ${#BASH_REMATCH[0]}))
  best_end=$((${#line} - 1))

  while [ "$best_start" -le "$best_end" ] && [ "${line:$best_start:1}" = " " ]; do
    best_start=$((best_start + 1))
  done

  while [ "$best_end" -ge "$best_start" ] && [ "${line:$best_end:1}" = " " ]; do
    best_end=$((best_end - 1))
  done

  extend_command_selection_to_block "$prompt_regex"
}

run_selector() {
  case "$kind" in
    url)
      select_url
      ;;
    path)
      select_path
      ;;
    command)
      select_command
      ;;
    sha)
      select_sha
      ;;
    *)
      show_message "unknown selector $kind"
      exit 0
      ;;
  esac
}
