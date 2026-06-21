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
    printf '%s' "off"
  else
    printf '%s' "$default_key"
  fi
}

spoony_copy_mode_tables() {
  printf '%s\n' copy-mode-vi copy-mode
}

restore_default_binding() {
  local table="$1"
  local key="$2"

  case "$table:$key" in
    'copy-mode-vi:?')
      tmux bind-key -T "$table" "$key" command-prompt -T search -p '(search up)' \
        "send-keys -X search-backward -- '%%'"
      ;;
    'copy-mode-vi:o')
      tmux bind-key -T "$table" "$key" send-keys -X other-end
      ;;
    'copy-mode-vi:P'|'copy-mode:P')
      tmux bind-key -T "$table" "$key" send-keys -X toggle-position
      ;;
    'copy-mode-vi:M')
      tmux bind-key -T "$table" "$key" send-keys -X middle-line
      ;;
    *)
      tmux unbind-key -T "$table" "$key" 2>/dev/null
      ;;
  esac
}

binding_is_spoony() {
  local binding="$1"
  local key="$2"

  case "$binding" in
    *'/scripts/select-on-line.sh'*|*'/scripts/open-selection.sh'*|*'/scripts/show-help.sh'*)
      return 0
      ;;
    *'send-keys -X select-line'*)
      [ "$key" = "x" ]
      return
      ;;
  esac

  return 1
}

restore_if_off() {
  local key="$1"
  local default_key="$2"
  local previous_key="$3"
  local table
  local binding

  if [ "$key" = "off" ]; then
    for table in $(spoony_copy_mode_tables); do
      binding="$(tmux list-keys -T "$table" "$default_key" 2>/dev/null)"

      if binding_is_spoony "$binding" "$default_key" ||
        { [ -z "$binding" ] && { [ "$previous_key" = "$default_key" ] || [ "$previous_key" = "off" ]; }; }; then
        restore_default_binding "$table" "$default_key"
      fi
    done
  fi
}

bind_copy_mode_key() {
  local key="$1"
  shift 1
  local table

  if [ -n "$key" ] && [ "$key" != "off" ]; then
    for table in $(spoony_copy_mode_tables); do
      tmux bind-key -T "$table" "$key" "$@"
    done
  fi
}

main() {
  local current_dir
  local url_key path_key url_cycle_key path_cycle_key
  local command_key command_block_key line_key open_key help_key
  local sha_key sha_next_key

  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  url_key="$(tmux show-option -gqv @spoony-url-key)"
  path_key="$(tmux show-option -gqv @spoony-path-key)"
  url_cycle_key="$(tmux show-option -gqv @spoony-url-cycle-key)"
  path_cycle_key="$(tmux show-option -gqv @spoony-path-cycle-key)"
  command_key="$(tmux show-option -gqv @spoony-command-key)"
  command_block_key="$(tmux show-option -gqv @spoony-command-block-key)"
  line_key="$(tmux show-option -gqv @spoony-line-key)"
  open_key="$(tmux show-option -gqv @spoony-open-key)"
  help_key="$(tmux show-option -gqv @spoony-help-key)"
  sha_key="$(tmux show-option -gqv @spoony-sha-key)"
  sha_next_key="$(tmux show-option -gqv @spoony-sha-next-key)"

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

  if [ -z "$help_key" ]; then
    help_key="?"
  fi

  if [ -z "$sha_key" ]; then
    sha_key="s"
  fi

  url_cycle_key="$(derive_cycle_key "$url_cycle_key" "$url_key" "U")"
  path_cycle_key="$(derive_cycle_key "$path_cycle_key" "$path_key" "P")"
  command_block_key="$(derive_cycle_key "$command_block_key" "$command_key" "M")"
  sha_next_key="$(derive_cycle_key "$sha_next_key" "$sha_key" "S")"

  restore_if_off "$url_key" "u" "$(tmux show-option -gqv @spoony-active-url-key)"
  restore_if_off "$path_key" "p" "$(tmux show-option -gqv @spoony-active-path-key)"
  restore_if_off "$url_cycle_key" "U" "$(tmux show-option -gqv @spoony-active-url-cycle-key)"
  restore_if_off "$path_cycle_key" "P" "$(tmux show-option -gqv @spoony-active-path-cycle-key)"
  restore_if_off "$command_key" "m" "$(tmux show-option -gqv @spoony-active-command-key)"
  restore_if_off "$command_block_key" "M" "$(tmux show-option -gqv @spoony-active-command-block-key)"
  restore_if_off "$line_key" "x" "$(tmux show-option -gqv @spoony-active-line-key)"
  restore_if_off "$open_key" "o" "$(tmux show-option -gqv @spoony-active-open-key)"
  restore_if_off "$help_key" "?" "$(tmux show-option -gqv @spoony-active-help-key)"
  restore_if_off "$sha_key" "s" "$(tmux show-option -gqv @spoony-active-sha-key)"
  restore_if_off "$sha_next_key" "S" "$(tmux show-option -gqv @spoony-active-sha-next-key)"

  # Publish the resolved keys so the help popup can render them dynamically.
  tmux set-option -g @spoony-active-url-key "$url_key"
  tmux set-option -g @spoony-active-url-cycle-key "$url_cycle_key"
  tmux set-option -g @spoony-active-path-key "$path_key"
  tmux set-option -g @spoony-active-path-cycle-key "$path_cycle_key"
  tmux set-option -g @spoony-active-command-key "$command_key"
  tmux set-option -g @spoony-active-command-block-key "$command_block_key"
  tmux set-option -g @spoony-active-line-key "$line_key"
  tmux set-option -g @spoony-active-open-key "$open_key"
  tmux set-option -g @spoony-active-help-key "$help_key"
  tmux set-option -g @spoony-active-sha-key "$sha_key"
  tmux set-option -g @spoony-active-sha-next-key "$sha_next_key"

  bind_copy_mode_key "$url_key" run-shell "bash '$current_dir/scripts/select-on-line.sh' url '#{pane_id}'"
  bind_copy_mode_key "$path_key" run-shell "bash '$current_dir/scripts/select-on-line.sh' path '#{pane_id}'"
  bind_copy_mode_key "$url_cycle_key" run-shell "bash '$current_dir/scripts/select-on-line.sh' url '#{pane_id}' cycle"
  bind_copy_mode_key "$path_cycle_key" run-shell "bash '$current_dir/scripts/select-on-line.sh' path '#{pane_id}' cycle"
  bind_copy_mode_key "$command_key" run-shell "bash '$current_dir/scripts/select-on-line.sh' command '#{pane_id}'"
  bind_copy_mode_key "$command_block_key" run-shell "bash '$current_dir/scripts/select-on-line.sh' command '#{pane_id}' block"
  bind_copy_mode_key "$sha_key" run-shell "bash '$current_dir/scripts/select-on-line.sh' sha '#{pane_id}'"
  bind_copy_mode_key "$sha_next_key" run-shell -b "bash '$current_dir/scripts/select-on-line.sh' sha '#{pane_id}' down"
  bind_copy_mode_key "$line_key" send-keys -X select-line
  bind_copy_mode_key "$open_key" send-keys -X copy-pipe-and-cancel "bash '$current_dir/scripts/open-selection.sh' '#{pane_id}'"
  bind_copy_mode_key "$help_key" display-popup -E -w 70 -h 25 -T " spoony " "bash '$current_dir/scripts/show-help.sh' '#{mode-keys}'; read -rsn1"
}

main "$@"
