ui::header() {
  local __scripter_title="$*"
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  if [ "$__scripter_ui_renderer" = plain ]; then
    printf '%s== %s ==\n' "$__scripter_ui_indent" "$__scripter_title" >&2
    return 0
  fi
  __scripter_ui_repeat "$__scripter_i_rule" "${#__scripter_title}"
  printf '%s%s%s%s%s\n%s%s%s%s\n' \
    "$__scripter_ui_indent" "$__scripter_c_bold" "$__scripter_c_accent" "$__scripter_title" "$__scripter_c_reset" \
    "$__scripter_ui_indent" "$__scripter_c_dim" "$__scripter_ui_out" "$__scripter_c_reset" >&2
}

ui::section() {
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  if [ "$__scripter_ui_renderer" = plain ]; then
    printf '%s-- %s\n' "$__scripter_ui_indent" "$*" >&2
  else
    printf '%s%s%s %s%s\n' "$__scripter_ui_indent" "$__scripter_c_bold" "$__scripter_i_arrow" "$*" "$__scripter_c_reset" >&2
  fi
}

ui::kv() {
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  printf '%s%s%-*s%s %s\n' "$__scripter_ui_indent" "$__scripter_c_dim" "$__scripter_ui_kv_width" "$1" \
    "$__scripter_c_reset" "${2:-}" >&2
}

ui::list() {
  local __scripter_item
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  for __scripter_item in "$@"; do
    printf '%s  %s %s\n' "$__scripter_ui_indent" "$__scripter_i_bullet" "$__scripter_item" >&2
  done
}
