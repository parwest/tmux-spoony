# find the nearest or next match while trimming punctuation.
# skip url fragments for paths and keep sha hits bounded to whole tokens.
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

    if [ "$match_kind" = "sha" ]; then
      local prev_char next_char
      prev_char=""
      next_char=""
      if [ "$start" -gt 0 ]; then
        prev_char="${search_line:$((start - 1)):1}"
      fi
      next_char="${search_line:$((end + 1)):1}"
      if { [ -n "$prev_char" ] && [[ "$prev_char" =~ [[:alnum:]_] ]]; } ||
        { [ -n "$next_char" ] && [[ "$next_char" =~ [[:alnum:]_] ]]; } ||
        [[ ! "$match" =~ [a-f] ]]; then
        advance=$((start - offset + ${#raw_match}))
        rest="${rest:$advance}"
        offset=$((offset + advance))
        continue
      fi
    fi

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
