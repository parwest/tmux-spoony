#!/usr/bin/env bash
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)/util.sh"

mode_keys="${1:-}"
if [ -z "$mode_keys" ] || [ "$mode_keys" = '#{mode-keys}' ]; then
  mode_keys="$(tmux show-option -gwv mode-keys 2>/dev/null)"
fi

case "$mode_keys" in
  vi) copy_table="copy-mode-vi" ;;
  emacs) copy_table="copy-mode" ;;
  *) copy_table="$mode_keys" ;;
esac

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
printf '   selectors list:\n'
printf '\n'
row "$(get @spoony-active-url-key)"           "select URL on cursor line"
row "$(get @spoony-active-url-cycle-key)"     "cycle to next URL on line"
row "$(get @spoony-active-path-key)"          "select path on cursor line"
row "$(get @spoony-active-path-cycle-key)"    "cycle to next path on line"
row "$(get @spoony-active-command-key)"       "select command after prompt"
row "$(get @spoony-active-command-block-key)" "select command + output block"
row "$(get @spoony-active-sha-key)"           "select git SHA on cursor line"
row "$(get @spoony-active-sha-next-key)"      "next git SHA below; press again at end to wrap"
row "$(get @spoony-active-line-key)"          "select the whole line"
row "$(get @spoony-active-open-key)"          "open the selection"
row "$(get @spoony-active-help-key)"          "show this help"
printf '\n'
if [ -n "$copy_table" ]; then
  printf '   current copy mode:  %s\n' "$copy_table"
  printf '\n'
fi
printf '   spoony looks for prompt character(s):  %s\n' "$(command_prompt_symbols)"
printf '\n'
printf '   override the prompt character in tmux.conf:\n'
printf "   set -g @spoony-command-prompt-regex '<your-regex>'\n"
printf '\n'
printf '   press any key to close\n'
