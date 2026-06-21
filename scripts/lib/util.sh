show_message() {
  tmux display-message "spoony: $*"
}

default_command_prompt_regex() {
  printf '%s' '((^|[[:space:]])[$#]|[[:space:]]>) +'
}

command_prompt_regex() {
  local regex
  regex="$(tmux show-option -gqv @spoony-command-prompt-regex)"
  if [ -z "$regex" ]; then
    regex="$(default_command_prompt_regex)"
  fi
  printf '%s' "$regex"
}

command_prompt_symbols() {
  local regex sym out=""
  regex="$(command_prompt_regex)"

  for sym in '$' '#' '>' '%' '❯' '➜' 'λ'; do
    if [[ "host ~ $sym cmd" =~ $regex ]]; then
      out="$out, $sym"
    fi
  done

  if [ -n "$out" ]; then
    printf '%s' "${out#, }"
  else
    printf '%s' "$regex"
  fi
}

is_unsigned_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
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

move_cursor() {
  local target_pane="$1"
  local direction="$2"
  local count="$3"

  if [ "$count" -gt 0 ]; then
    tmux send-keys -t "$target_pane" -N "$count" -X "$direction"
  fi
}
