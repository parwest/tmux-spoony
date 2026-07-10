#!/usr/bin/env bash

current_dir=""

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

encode_key() {
  local key="$1"
  local out="" i c

  for ((i = 0; i < ${#key}; i++)); do
    c="${key:$i:1}"
    if [[ "$c" =~ ^[A-Za-z0-9]$ ]]; then
      out="$out$c"
    else
      out="$out$(printf '_%02x' "'$c")"
    fi
  done

  printf '%s' "$out"
}

saved_option_name() {
  printf '@spoony-saved-%s-%s' "$1" "$(encode_key "$2")"
}

binding_is_spoony() {
  local binding="$1"
  local name="$2"

  case "$binding" in
    *'/scripts/select-on-line.sh'*|*'/scripts/open-selection.sh'*|*'/scripts/show-help.sh'*)
      return 0
      ;;
    *'send-keys -X select-line'*)
      [ "$name" = "line" ]
      return
      ;;
  esac

  return 1
}

# ask a throwaway config-less tmux server what the key's default binding is.
restore_pristine_default() {
  local table="$1"
  local key="$2"
  local line
  local defaults_socket="spoony-defaults-$$"

  line="$(tmux -L "$defaults_socket" -f /dev/null start-server \; list-keys -T "$table" "$key" 2>/dev/null)"
  tmux -L "$defaults_socket" kill-server 2>/dev/null

  if [ -n "$line" ]; then
    printf '%s\n' "$line" | tmux source-file -
  else
    tmux unbind-key -T "$table" "$key" 2>/dev/null
  fi
}

release_key() {
  local table="$1"
  local key="$2"
  local name="$3"
  local saved_opt saved existing

  saved_opt="$(saved_option_name "$table" "$key")"
  saved="$(tmux show-option -gqv "$saved_opt")"

  if [ -z "$saved" ]; then
    existing="$(tmux list-keys -T "$table" "$key" 2>/dev/null)"
    if [ -n "$existing" ] && binding_is_spoony "$existing" "$name"; then
      restore_pristine_default "$table" "$key"
    fi
    return
  fi

  tmux set-option -gu "$saved_opt"

  case "$saved" in
    none)
      tmux unbind-key -T "$table" "$key" 2>/dev/null
      ;;
    default)
      restore_pristine_default "$table" "$key"
      ;;
    *)
      printf '%s\n' "$saved" | tmux source-file -
      ;;
  esac
}

claim_key() {
  local table="$1"
  local key="$2"
  local name="$3"
  shift 3
  local saved_opt existing

  saved_opt="$(saved_option_name "$table" "$key")"

  if [ -z "$(tmux show-option -gqv "$saved_opt")" ]; then
    existing="$(tmux list-keys -T "$table" "$key" 2>/dev/null)"
    if [ -z "$existing" ]; then
      tmux set-option -g "$saved_opt" none
    elif binding_is_spoony "$existing" "$name"; then
      tmux set-option -g "$saved_opt" default
    else
      tmux set-option -g "$saved_opt" "$existing"
    fi
  fi

  tmux bind-key -T "$table" "$key" "$@"
}

bind_selector() {
  local name="$1"
  local key="$2"
  local table

  if [ -z "$key" ] || [ "$key" = "off" ]; then
    return
  fi

  for table in $(spoony_copy_mode_tables); do
    case "$name" in
      url|path|command|sha)
        claim_key "$table" "$key" "$name" run-shell "bash '$current_dir/scripts/select-on-line.sh' $name '#{pane_id}'"
        ;;
      url-cycle)
        claim_key "$table" "$key" "$name" run-shell "bash '$current_dir/scripts/select-on-line.sh' url '#{pane_id}' cycle"
        ;;
      path-cycle)
        claim_key "$table" "$key" "$name" run-shell "bash '$current_dir/scripts/select-on-line.sh' path '#{pane_id}' cycle"
        ;;
      command-block)
        claim_key "$table" "$key" "$name" run-shell "bash '$current_dir/scripts/select-on-line.sh' command '#{pane_id}' block"
        ;;
      sha-next)
        claim_key "$table" "$key" "$name" run-shell -b "bash '$current_dir/scripts/select-on-line.sh' sha '#{pane_id}' down"
        ;;
      line)
        claim_key "$table" "$key" "$name" send-keys -X select-line
        ;;
      open)
        claim_key "$table" "$key" "$name" send-keys -X copy-pipe-and-cancel "bash '$current_dir/scripts/open-selection.sh' '#{pane_id}'"
        ;;
      help)
        claim_key "$table" "$key" "$name" display-popup -E -w 70 -h 25 -T " spoony " "bash '$current_dir/scripts/show-help.sh' '#{mode-keys}'; read -rsn1"
        ;;
    esac
  done
}

main() {
  local names defaults keys
  local i name key prev explicit table

  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  names=(url url-cycle path path-cycle command command-block sha sha-next line open help)
  defaults=(u U p P m M s S x o '?')
  keys=()

  # cycle/block/next keys derive from the base key resolved just before them.
  for i in "${!names[@]}"; do
    name="${names[$i]}"
    explicit="$(tmux show-option -gqv "@spoony-${name}-key")"

    case "$name" in
      url-cycle|path-cycle|command-block|sha-next)
        key="$(derive_cycle_key "$explicit" "${keys[$((i - 1))]}" "${defaults[$i]}")"
        ;;
      *)
        key="${explicit:-${defaults[$i]}}"
        ;;
    esac

    keys[$i]="$key"
  done

  # release remapped or disabled keys before claiming, so selectors that
  # swap keys between runs don't restore over each other.
  for i in "${!names[@]}"; do
    prev="$(tmux show-option -gqv "@spoony-active-${names[$i]}-key")"

    if [ -n "$prev" ] && [ "$prev" != "off" ] && [ "$prev" != "${keys[$i]}" ]; then
      for table in $(spoony_copy_mode_tables); do
        release_key "$table" "$prev" "${names[$i]}"
      done
    fi
  done

  for i in "${!names[@]}"; do
    bind_selector "${names[$i]}" "${keys[$i]}"
    # Publish the resolved keys so the help popup can render them dynamically.
    tmux set-option -g "@spoony-active-${names[$i]}-key" "${keys[$i]}"
  done
}

main "$@"
