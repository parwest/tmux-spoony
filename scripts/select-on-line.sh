#!/usr/bin/env bash
set -u

show_message() {
  tmux display-message "spoony: $*"
}

is_unsigned_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

visible_cursor_line() {
  local target_pane="$1"
  local cursor_row="$2"

  if [ -z "$cursor_row" ]; then
    return
  fi

  tmux capture-pane -p -t "$target_pane" -S "$cursor_row" -E "$cursor_row" 2>/dev/null |
    sed -n '1p'
}

trim_trailing_punctuation() {
  local token="$1"
  local last opener closer opens closes

  while [ -n "$token" ]; do
    last="${token: -1}"
    case "$last" in
      .|,|";"|:|"!"|"?")
        token="${token%?}"
        ;;
      ")"|"]"|"}")
        case "$last" in
          ")") opener="("; closer=")" ;;
          "]") opener="["; closer="]" ;;
          "}") opener="{"; closer="}" ;;
        esac

        opens="${token//[^"$opener"]/}"
        closes="${token//[^"$closer"]/}"
        if [ "${#closes}" -gt "${#opens}" ]; then
          token="${token%?}"
        else
          break
        fi
        ;;
      *)
        break
        ;;
    esac
  done

  printf '%s' "$token"
}

find_match() {
  local regex="$1"
  local match_mode="$2"
  local search_line="$3"
  local cursor_col="$4"
  local match_kind="$5"

  local best_start=-1
  local best_end=-1
  local best_distance=999999
  local first_start=-1
  local first_end=-1
  local cycle_start=-1
  local cycle_end=-1

  local rest="$search_line"
  local offset=0
  local raw_match match prefix start end distance advance

  while [[ "$rest" =~ $regex ]]; do
    raw_match="${BASH_REMATCH[0]}"
    match="$(trim_trailing_punctuation "$raw_match")"

    if [ -z "$match" ]; then
      break
    fi

    prefix="${rest%%"$raw_match"*}"
    start=$((offset + ${#prefix}))

    if [ "$match_kind" = "path" ] &&
      { { [ "$start" -ge 1 ] && [ "${search_line:$((start - 1)):3}" = "://" ]; } ||
        { [ "$start" -ge 2 ] && [ "${search_line:$((start - 2)):3}" = "://" ]; }; }; then
      advance=$((start - offset + ${#raw_match}))
      rest="${rest:$advance}"
      offset=$((offset + advance))
      continue
    fi

    end=$((start + ${#match} - 1))

    if [ "$first_start" -lt 0 ]; then
      first_start="$start"
      first_end="$end"
    fi

    if [ "$match_mode" = "cycle" ]; then
      if [ "$cycle_start" -lt 0 ] && [ "$start" -gt "$cursor_col" ]; then
        cycle_start="$start"
        cycle_end="$end"
      fi
    else
      if [ "$cursor_col" -lt "$start" ]; then
        distance=$((start - cursor_col))
      elif [ "$cursor_col" -gt "$end" ]; then
        distance=$((cursor_col - end))
      else
        distance=0
      fi

      if [ "$distance" -lt "$best_distance" ]; then
        best_distance="$distance"
        best_start="$start"
        best_end="$end"
      fi
    fi

    advance=$((start - offset + ${#raw_match}))
    rest="${rest:$advance}"
    offset=$((offset + advance))
  done

  if [ "$match_mode" = "cycle" ]; then
    if [ "$cycle_start" -ge 0 ]; then
      best_start="$cycle_start"
      best_end="$cycle_end"
    else
      best_start="$first_start"
      best_end="$first_end"
    fi
  fi

  printf '%s %s\n' "$best_start" "$best_end"
}

load_joined_url_context() {
  local regex="$1"
  local current_line="$line"
  local original_cursor_x="$cursor_x"
  local start end joined needle trimmed idx line_len prefix pane_width wrap_adjust

  if [ -z "$cursor_y" ] || [ -z "$current_line" ]; then
    return
  fi

  start=$((cursor_y - 12))
  if [ "$start" -lt 0 ]; then
    start=0
  fi
  end=$((cursor_y + 4))

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

move_cursor() {
  local target_pane="$1"
  local direction="$2"
  local count="$3"

  if [ "$count" -gt 0 ]; then
    tmux send-keys -t "$target_pane" -N "$count" -X "$direction"
  fi
}

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

load_copy_context() {
  cursor_x="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_x}')"
  cursor_y="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_y}')"
  line="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_line}')"

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
  done < <(tmux capture-pane -p -t "$pane_id" -S "$cursor_y" 2>/dev/null)

  if [ "$block_end" -gt 0 ]; then
    best_end=$((${#end_row} - 1))
    while [ "$best_end" -ge 0 ] && [ "${end_row:$best_end:1}" = " " ]; do
      best_end=$((best_end - 1))
    done
    end_lines_down="$block_end"
  fi
}

select_command() {
  local prompt_regex visible_line

  label="command"
  prompt_regex="$(tmux show-option -gqv @spoony-command-prompt-regex)"
  if [ -z "$prompt_regex" ]; then
    prompt_regex='^.+[$#>] +'
  fi

  visible_line="$(visible_cursor_line "$pane_id" "$cursor_y")"
  if [ -n "$visible_line" ] && [[ "$visible_line" =~ $prompt_regex ]]; then
    line="$visible_line"
  fi

  if ! [[ "$line" =~ $prompt_regex ]]; then
    show_message "no command prompt on cursor line"
    exit 0
  fi

  best_start="${#BASH_REMATCH[0]}"
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
    *)
      show_message "unknown selector $kind"
      exit 0
      ;;
  esac
}

main() {
  local kind="${1:-}"
  local pane_id="${2:-}"
  local mode="${3:-nearest}"
  local cursor_x cursor_y line label best_start best_end end_lines_down

  if [ -z "$kind" ] || [ -z "$pane_id" ]; then
    show_message "missing selector arguments"
    exit 0
  fi

  if [ "$mode" != "cycle" ] && [ "$mode" != "block" ]; then
    mode="nearest"
  fi

  load_copy_context

  label="$kind"
  best_start=-1
  best_end=-1
  end_lines_down=0

  run_selector

  if [ "$best_start" -lt 0 ] || [ "$best_end" -lt 0 ] ||
    { [ "$end_lines_down" -eq 0 ] && [ "$best_start" -gt "$best_end" ]; }; then
    show_message "no $label on cursor line"
    exit 0
  fi

  select_range "$pane_id" "$cursor_x" "$best_start" "$best_end" "$end_lines_down"
}

main "$@"
