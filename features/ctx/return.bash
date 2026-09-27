__scripter_ret() {
  if [ -n "$1" ]; then
    printf -v "$1" '%s' "$2"
  else
    printf '%s\n' "$2"
  fi
}

__scripter_ret_var() {
  __scripter_ret_to=""
  if [ "${1:-}" = -v ]; then __scripter_ret_to=$2; fi
}

__scripter_flag() {
  if "$@"; then printf 1; fi
}
