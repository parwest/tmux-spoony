#!/usr/bin/env bash
set -u

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

# shellcheck source=lib/util.sh
. "$lib_dir/util.sh"
# shellcheck source=lib/context.sh
. "$lib_dir/context.sh"
# shellcheck source=lib/match.sh
. "$lib_dir/match.sh"
# shellcheck source=lib/select.sh
. "$lib_dir/select.sh"
# shellcheck source=lib/selectors.sh
. "$lib_dir/selectors.sh"

main() {
  local kind="${1:-}"
  local pane_id="${2:-}"
  local mode="${3:-nearest}"
  local cursor_x cursor_y line label best_start best_end end_lines_down scroll_pos

  if [ -z "$kind" ] || [ -z "$pane_id" ]; then
    show_message "missing selector arguments"
    exit 0
  fi

  if [ "$mode" != "cycle" ] && [ "$mode" != "block" ] && [ "$mode" != "down" ]; then
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

  if [ "$mode" = "down" ]; then
    select_on_line_offset "$pane_id" "$end_lines_down" "$best_start" "$best_end"
  else
    select_range "$pane_id" "$cursor_x" "$best_start" "$best_end" "$end_lines_down"
  fi
}

main "$@"
