#!/usr/bin/env bash

derive_cycle_key() {
  local explicit_key="$1"
  local base_key="$2"
  local default_key="$3"

  if [ -n "$explicit_key" ]; then
    printf '%s' "$explicit_key"
  elif [ "$base_key" = "off" ]; then
    printf '%s' "off"
  elif [[ "$base_key" =~ ^[a-z]$ ]]; then
    printf '%s' "$base_key" | tr '[:lower:]' '[:upper:]'
  elif [ "$default_key" = "$base_key" ]; then
    # the fallback would overwrite the user's base binding
    printf '%s' "off"
  else
    printf '%s' "$default_key"
  fi
}

unbind_if_off() {
  local key="$1"
  local default_key="$2"

  if [ "$key" = "off" ]; then
    tmux unbind-key -T copy-mode-vi "$default_key" 2>/dev/null
  fi
}

bind_copy_mode_key() {
  local key="$1"
  local default_key="$2"
  shift 2

  if [ -n "$key" ] && [ "$key" != "off" ]; then
    tmux bind-key -T copy-mode-vi "$key" "$@"
  fi
}

main() {
  local current_dir
  local url_key path_key url_cycle_key path_cycle_key
  local command_key command_block_key line_key open_key

  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  url_key="$(tmux show-option -gqv @spoony-url-key)"
  path_key="$(tmux show-option -gqv @spoony-path-key)"
  url_cycle_key="$(tmux show-option -gqv @spoony-url-cycle-key)"
  path_cycle_key="$(tmux show-option -gqv @spoony-path-cycle-key)"
  command_key="$(tmux show-option -gqv @spoony-command-key)"
  command_block_key="$(tmux show-option -gqv @spoony-command-block-key)"
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

  url_cycle_key="$(derive_cycle_key "$url_cycle_key" "$url_key" "U")"
  path_cycle_key="$(derive_cycle_key "$path_cycle_key" "$path_key" "P")"
  command_block_key="$(derive_cycle_key "$command_block_key" "$command_key" "M")"

  unbind_if_off "$url_key" "u"
  unbind_if_off "$path_key" "p"
  unbind_if_off "$url_cycle_key" "U"
  unbind_if_off "$path_cycle_key" "P"
  unbind_if_off "$command_key" "m"
  unbind_if_off "$command_block_key" "M"
  unbind_if_off "$line_key" "x"
  unbind_if_off "$open_key" "o"

  bind_copy_mode_key "$url_key" "u" run-shell "bash '$current_dir/scripts/select-on-line.sh' url '#{pane_id}'"
  bind_copy_mode_key "$path_key" "p" run-shell "bash '$current_dir/scripts/select-on-line.sh' path '#{pane_id}'"
  bind_copy_mode_key "$url_cycle_key" "U" run-shell "bash '$current_dir/scripts/select-on-line.sh' url '#{pane_id}' cycle"
  bind_copy_mode_key "$path_cycle_key" "P" run-shell "bash '$current_dir/scripts/select-on-line.sh' path '#{pane_id}' cycle"
  bind_copy_mode_key "$command_key" "m" run-shell "bash '$current_dir/scripts/select-on-line.sh' command '#{pane_id}'"
  bind_copy_mode_key "$command_block_key" "M" run-shell "bash '$current_dir/scripts/select-on-line.sh' command '#{pane_id}' block"
  bind_copy_mode_key "$line_key" "x" send-keys -X select-line
  bind_copy_mode_key "$open_key" "o" send-keys -X copy-pipe-and-cancel "bash '$current_dir/scripts/open-selection.sh' '#{pane_id}'"
}

main "$@"
