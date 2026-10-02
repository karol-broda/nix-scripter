__scripter_location() {
  local __scripter_line=$1 __scripter_seg __scripter_start __scripter_end __scripter_file
  for __scripter_seg in "${__scripter_srcmap[@]}"; do
    read -r __scripter_start __scripter_end __scripter_file <<<"$__scripter_seg"
    if [ "$__scripter_line" -ge "$__scripter_start" ] && [ "$__scripter_line" -le "$__scripter_end" ]; then
      __scripter_loc="$__scripter_file:$((__scripter_line - __scripter_start + 1))"
      return 0
    fi
  done
  __scripter_loc="$__scripter_name:$__scripter_line (generated)"
}

core::stacktrace() {
  local __scripter_i=${1:-1}
  for ((; __scripter_i < ${#FUNCNAME[@]}; __scripter_i++)); do
    __scripter_location "${BASH_LINENO[__scripter_i - 1]}"
    printf '    at %s (%s)\n' "${FUNCNAME[__scripter_i]}" "$__scripter_loc" >&2
  done
}

# Inside a function, bash 3 reports the definition line instead of the failing one.
__scripter_line_note() {
  __scripter_note=""
  if [ "${BASH_VERSINFO[0]}" -lt 4 ] && [ -n "${1:-}" ] && [ "$1" != main ]; then
    __scripter_note=", function start"
  fi
}

__scripter_on_err() {
  local __scripter_rc=$1 __scripter_cmd=$3
  if [ "${BASH_SUBSHELL:-0}" -gt 0 ]; then
    return 0
  fi
  __scripter_location "$2"
  __scripter_line_note "${FUNCNAME[1]:-}"
  printf '%s: error: command failed with exit code %s\n    %s\n    at %s (%s%s)\n' \
    "$__scripter_name" "$__scripter_rc" "$__scripter_cmd" "${FUNCNAME[1]:-main}" "$__scripter_loc" "$__scripter_note" >&2
  local __scripter_callers_of_failing_function=3
  core::stacktrace "$__scripter_callers_of_failing_function"
}

if [ -n "$__scripter_core_stacktrace" ]; then
  set -o errtrace
  trap '__scripter_on_err "$?" "$LINENO" "$BASH_COMMAND"' ERR
fi
