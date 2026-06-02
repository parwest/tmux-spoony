#!/usr/bin/env bash
set -u

visible_cursor_line() {
  if [ -z "$cursor_y" ]; then
    return
  fi

  tmux capture-pane -p -t "$pane_id" -S "$cursor_y" -E "$cursor_y" 2>/dev/null |
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
  regex="$1"
  mode="${2:-nearest}"

  best_start=-1
  best_end=-1
  best_distance=999999
  first_start=-1
  first_end=-1
  cycle_start=-1
  cycle_end=-1

  rest="$line"
  offset=0

  while [[ "$rest" =~ $regex ]]; do
    raw_match="${BASH_REMATCH[0]}"
    match="$(trim_trailing_punctuation "$raw_match")"

    if [ -z "$match" ]; then
      break
    fi

    prefix="${rest%%"$raw_match"*}"
    start=$((offset + ${#prefix}))

    if [ "$kind" = "path" ] &&
      { { [ "$start" -ge 1 ] && [ "${line:$((start - 1)):3}" = "://" ]; } ||
        { [ "$start" -ge 2 ] && [ "${line:$((start - 2)):3}" = "://" ]; }; }; then
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

    if [ "$mode" = "cycle" ]; then
      if [ "$cycle_start" -lt 0 ] && [ "$start" -gt "$cursor_x" ]; then
        cycle_start="$start"
        cycle_end="$end"
      fi
    else
      if [ "$cursor_x" -lt "$start" ]; then
        distance=$((start - cursor_x))
      elif [ "$cursor_x" -gt "$end" ]; then
        distance=$((cursor_x - end))
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

  if [ "$mode" = "cycle" ]; then
    if [ "$cycle_start" -ge 0 ]; then
      best_start="$cycle_start"
      best_end="$cycle_end"
    else
      best_start="$first_start"
      best_end="$first_end"
    fi
  fi
}

kind="${1:-}"
pane_id="${2:-}"
mode="${3:-nearest}"

if [ -z "$kind" ] || [ -z "$pane_id" ]; then
  tmux display-message "spoony: missing selector arguments"
  exit 0
fi

if [ "$mode" != "cycle" ]; then
  mode="nearest"
fi

cursor_x="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_x}')"
cursor_y="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_y}')"
line="$(tmux display-message -p -t "$pane_id" '#{copy_cursor_line}')"

if [ -z "$line" ]; then
  tmux display-message "spoony: no copy-mode line found"
  exit 0
fi

if ! [[ "$cursor_x" =~ ^[0-9]+$ ]]; then
  cursor_x=0
fi

if ! [[ "$cursor_y" =~ ^[0-9]+$ ]]; then
  cursor_y=""
fi

move_cursor() {
  direction="$1"
  count="$2"

  i=0
  while [ "$i" -lt "$count" ]; do
    tmux send-keys -t "$pane_id" -X "$direction"
    i=$((i + 1))
  done
}

select_range() {
  start="$1"
  end="$2"

  tmux send-keys -t "$pane_id" -X clear-selection

  delta=$((start - cursor_x))
  if [ "$delta" -lt 0 ]; then
    move_cursor cursor-left "$((-delta))"
  elif [ "$delta" -gt 0 ]; then
    move_cursor cursor-right "$delta"
  fi

  tmux send-keys -t "$pane_id" -X begin-selection
  move_cursor cursor-right "$((end - start))"
}

case "$kind" in
  url)
    label="URL"
    find_match '(https?|ftp)://[^[:space:]<>"'\'']+' "$mode"
    ;;
  path)
    label="path"
    visible_line="$(visible_cursor_line)"
    if [ -n "$visible_line" ]; then
      line="$visible_line"
      if [ "$cursor_x" -gt "${#line}" ]; then
        cursor_x="${#line}"
      fi
    fi

    find_match '(~|/|\./|\.\./|[[:alnum:]_.-]+/)[^[:space:]<>"'\'']+' "$mode"
    ;;
  command)
    label="command"
    prompt_regex="$(tmux show-option -gqv @spoony-command-prompt-regex)"
    if [ -z "$prompt_regex" ]; then
      prompt_regex='^.+[$#>] +'
    fi

    visible_line="$(visible_cursor_line)"
    if [ -n "$visible_line" ] && [[ "$visible_line" =~ $prompt_regex ]]; then
      line="$visible_line"
    fi

    if ! [[ "$line" =~ $prompt_regex ]]; then
      tmux display-message "spoony: no command prompt on cursor line"
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
    ;;
  *)
    tmux display-message "spoony: unknown selector $kind"
    exit 0
    ;;
esac

if [ "$best_start" -lt 0 ] || [ "$best_start" -gt "$best_end" ]; then
  tmux display-message "spoony: no $label on cursor line"
  exit 0
fi

select_range "$best_start" "$best_end"
