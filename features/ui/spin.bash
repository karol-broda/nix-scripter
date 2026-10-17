__scripter_ui_spin_fancy() {
  local __scripter_msg=$1 __scripter_i=0
  shift
  need_cmd mktemp sleep rm cat
  __scripter_ui_spin_log=$(mktemp)
  (
    set -e
    "$@"
  ) >"$__scripter_ui_spin_log" 2>&1 &
  __scripter_ui_spin_pid=$!
  __scripter_ui_hide_cursor
  while kill -0 "$__scripter_ui_spin_pid" 2>/dev/null; do
    printf '\r\e[K%s%s%s%s %s' "$__scripter_ui_indent" "$__scripter_c_accent" \
      "${__scripter_ui_frames[__scripter_i % ${#__scripter_ui_frames[@]}]}" "$__scripter_c_reset" "$__scripter_msg" >&2
    __scripter_i=$((__scripter_i + 1))
    sleep 0.1
  done
  __scripter_ui_rc=0
  wait "$__scripter_ui_spin_pid" || __scripter_ui_rc=$?
  __scripter_ui_spin_pid=""
  printf '\r\e[K' >&2
  __scripter_ui_show_cursor
}

__scripter_ui_spin_report() {
  local __scripter_msg=$1 __scripter_duration=$2
  if [ "$__scripter_ui_rc" -eq 0 ]; then
    ui::success "$__scripter_msg $__scripter_c_dim($__scripter_duration)$__scripter_c_reset"
    return 0
  fi
  ui::error "$__scripter_msg $__scripter_c_dim(exit code $__scripter_ui_rc, $__scripter_duration)$__scripter_c_reset"
  if [ -n "$__scripter_ui_spin_log" ]; then
    sed "s/^/$__scripter_ui_indent  /" "$__scripter_ui_spin_log" >&2
  fi
}

# ui::spin <message> -- <command>...  (output is shown only on failure)
ui::spin() {
  local __scripter_msg=$1 __scripter_start
  shift
  if [ "${1:-}" = -- ]; then shift; fi
  __scripter_ui_init
  __scripter_ui_spin_log=""
  __scripter_now_ms
  __scripter_start=$__scripter_ms
  if [ "$__scripter_ui_renderer" = fancy ]; then
    __scripter_ui_spin_fancy "$__scripter_msg" "$@"
  else
    ui::info "$__scripter_msg ..."
    __scripter_ui_run "$@"
  fi
  __scripter_elapsed_since "$__scripter_start"
  __scripter_ui_spin_report "$__scripter_msg" "$__scripter_ui_out"
  if [ -n "$__scripter_ui_spin_log" ]; then rm -f "$__scripter_ui_spin_log"; fi
  return "$__scripter_ui_rc"
}
