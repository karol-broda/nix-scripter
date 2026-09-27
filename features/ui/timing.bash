__scripter_now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local __scripter_t=${EPOCHREALTIME//[!0-9]/}
    __scripter_ms=$((10#$__scripter_t / 1000))
  else
    __scripter_ms=$((SECONDS * 1000))
  fi
}

__scripter_format_duration() {
  local __scripter_t=$1
  if [ -z "${EPOCHREALTIME:-}" ]; then
    __scripter_ui_out="$((__scripter_t / 1000))s"
  elif [ "$__scripter_t" -lt 1000 ]; then
    __scripter_ui_out="${__scripter_t}ms"
  elif [ "$__scripter_t" -lt 60000 ]; then
    __scripter_ui_out="$((__scripter_t / 1000)).$(((__scripter_t % 1000) / 100))s"
  else
    printf -v __scripter_ui_out '%dm%02ds' "$((__scripter_t / 60000))" "$(((__scripter_t % 60000) / 1000))"
  fi
}

__scripter_elapsed_since() {
  __scripter_now_ms
  __scripter_format_duration "$((__scripter_ms - $1))"
}
