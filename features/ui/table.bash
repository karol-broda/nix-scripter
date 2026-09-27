__scripter_ui_table_measure() {
  local __scripter_i __scripter_cells
  IFS=$'\t' read -r -a __scripter_cells <<<"$1"
  for ((__scripter_i = 0; __scripter_i < ${#__scripter_cells[@]}; __scripter_i++)); do
    if [ "${#__scripter_cells[__scripter_i]}" -gt "${__scripter_ui_widths[__scripter_i]:-0}" ]; then
      __scripter_ui_widths[__scripter_i]=${#__scripter_cells[__scripter_i]}
    fi
  done
}

__scripter_ui_table_format() {
  local __scripter_i __scripter_last __scripter_cell __scripter_cells
  IFS=$'\t' read -r -a __scripter_cells <<<"$1"
  __scripter_last=$((${#__scripter_cells[@]} - 1))
  __scripter_ui_out=""
  for ((__scripter_i = 0; __scripter_i < __scripter_last; __scripter_i++)); do
    printf -v __scripter_cell '%-*s  ' "${__scripter_ui_widths[__scripter_i]}" "${__scripter_cells[__scripter_i]}"
    __scripter_ui_out=$__scripter_ui_out$__scripter_cell
  done
  __scripter_ui_out=$__scripter_ui_out${__scripter_cells[__scripter_last]}
}

__scripter_ui_table_rule() {
  local __scripter_i __scripter_total=0
  for ((__scripter_i = 0; __scripter_i < ${#__scripter_ui_widths[@]}; __scripter_i++)); do
    __scripter_total=$((__scripter_total + __scripter_ui_widths[__scripter_i] + 2))
  done
  __scripter_ui_repeat "$__scripter_i_rule" "$((__scripter_total - 2))"
  printf '%s%s%s%s\n' "$__scripter_ui_indent" "$__scripter_c_dim" "$__scripter_ui_out" "$__scripter_c_reset" >&2
}

# ui::table [--no-header] < rows.tsv
ui::table() {
  local __scripter_header=1 __scripter_line __scripter_r
  local -a __scripter_rows=()
  if [ "${1:-}" = --no-header ]; then __scripter_header=""; fi
  __scripter_ui_init
  if [ "$__scripter_ui_renderer" = plain ]; then
    cat >&2
    return 0
  fi
  __scripter_ui_widths=()
  while IFS= read -r __scripter_line || [ -n "$__scripter_line" ]; do
    __scripter_rows+=("$__scripter_line")
    __scripter_ui_table_measure "$__scripter_line"
  done
  for ((__scripter_r = 0; __scripter_r < ${#__scripter_rows[@]}; __scripter_r++)); do
    __scripter_ui_table_format "${__scripter_rows[__scripter_r]}"
    if [ "$__scripter_r" -eq 0 ] && [ -n "$__scripter_header" ]; then
      printf '%s%s%s%s\n' "$__scripter_ui_indent" "$__scripter_c_bold" "$__scripter_ui_out" "$__scripter_c_reset" >&2
      __scripter_ui_table_rule
    else
      printf '%s%s\n' "$__scripter_ui_indent" "$__scripter_ui_out" >&2
    fi
  done
}
