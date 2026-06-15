#!/usr/bin/env bash
set -u

# Renders the spoony cheatsheet from the keys resolved at plugin load time.
# tmux-spoony.tmux publishes them as @spoony-active-* options, so this popup
# always reflects the user's actual bindings (remaps, off, derived cycle keys).

get() {
  tmux show-option -gqv "$1"
}

row() {
  local key="$1"
  local desc="$2"

  if [ -z "$key" ] || [ "$key" = "off" ]; then
    return
  fi

  printf '   %-7s %s\n' "$key" "$desc"
}

printf '\n'
printf '   spoony — copy-mode selectors\n'
printf '\n'
row "$(get @spoony-active-url-key)"           "select URL on cursor line"
row "$(get @spoony-active-url-cycle-key)"     "cycle to next URL on line"
row "$(get @spoony-active-path-key)"          "select path on cursor line"
row "$(get @spoony-active-path-cycle-key)"    "cycle to next path on line"
row "$(get @spoony-active-command-key)"       "select command after prompt"
row "$(get @spoony-active-command-block-key)" "select command + output block"
row "$(get @spoony-active-line-key)"          "select the whole line"
row "$(get @spoony-active-open-key)"          "open the selection"
row "$(get @spoony-active-help-key)"          "show this help"
printf '\n'
printf '   y       yank the selection (tmux copy-mode-vi)\n'
printf '\n'
printf '   press any key to close\n'
