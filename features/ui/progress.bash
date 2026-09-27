__scripter_ui_progress_bar() {
  local __scripter_pct=$1 __scripter_msg=$2 __scripter_done=$3 __scripter_fill __scripter_bar
  __scripter_fill=$((__scripter_pct * 30 / 100))
  __scripter_ui_repeat "$__scripter_i_bar_full" "$__scripter_fill"
  __scripter_bar=$__scripter_ui_out
  __scripter_ui_repeat "$__scripter_i_bar_empty" "$((30 - __scripter_fill))"
  printf '\r\e[K%s%s%s%s%s %3d%% %s' "$__scripter_ui_indent" "$__scripter_c_accent" "$__scripter_bar" \
    "$__scripter_c_dim$__scripter_ui_out" "$__scripter_c_reset" "$__scripter_pct" "$__scripter_msg" >&2
  if [ -n "$__scripter_done" ]; then printf '\n' >&2; fi
}

__scripter_ui_progress_steps() {
  local __scripter_pct=$1 __scripter_msg=$2 __scripter_done=$3 __scripter_step=$(($1 / 10))
  if [ "$__scripter_step" != "${__scripter_ui_progress_last:-}" ]; then
    __scripter_ui_progress_last=$__scripter_step
    ui::info "${__scripter_msg:+$__scripter_msg: }$__scripter_pct%"
  fi
  if [ -n "$__scripter_done" ]; then __scripter_ui_progress_last=""; fi
}

__scripter_clamp_percent() {
  local __scripter_total=$2
  if [ "$__scripter_total" -le 0 ]; then __scripter_total=1; fi
  __scripter_ui_pct=$(($1 * 100 / __scripter_total))
  if [ "$__scripter_ui_pct" -gt 100 ]; then __scripter_ui_pct=100; fi
  if [ "$__scripter_ui_pct" -lt 0 ]; then __scripter_ui_pct=0; fi
}

# ui::progress <current> <total> [message]
ui::progress() {
  local __scripter_done=""
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  __scripter_clamp_percent "$1" "$2"
  if [ "$1" -ge "$2" ]; then __scripter_done=1; fi
  if [ "$__scripter_ui_renderer" = fancy ]; then
    __scripter_ui_progress_bar "$__scripter_ui_pct" "${3:-}" "$__scripter_done"
  else
    __scripter_ui_progress_steps "$__scripter_ui_pct" "${3:-}" "$__scripter_done"
  fi
}
