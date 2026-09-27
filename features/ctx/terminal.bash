ctx::is_tty() {
  [ -t 2 ]
}

ctx::is_interactive() {
  [ -t 0 ] && [ -t 2 ] && ! ctx::is_ci
}

__scripter_env_enabled() {
  [ -n "${1:-}" ] && [ "$1" != 0 ]
}

__scripter_detect_color() {
  case ${SCRIPTER_COLOR:-auto} in
    always | yes | 1) return 0 ;;
    never | no | 0) return 1 ;;
  esac
  if [ -n "${NO_COLOR:-}" ]; then return 1; fi
  if __scripter_env_enabled "${FORCE_COLOR:-}" || __scripter_env_enabled "${CLICOLOR_FORCE:-}"; then return 0; fi
  if [ "${TERM:-}" = dumb ]; then return 1; fi
  if ctx::is_ci; then
    __scripter_ci_renders_color
    return
  fi
  ctx::is_tty
}

ctx::color() {
  if [ -z "${__scripter_color+x}" ]; then
    __scripter_color=""
    if __scripter_detect_color; then __scripter_color=1; fi
  fi
  [ -n "$__scripter_color" ]
}

ctx::renderer() {
  local __scripter_r
  __scripter_ret_var "$@"
  __scripter_ensure_ci
  case ${SCRIPTER_UI:-auto} in
    fancy | plain) __scripter_r=$SCRIPTER_UI ;;
    ci) __scripter_r="ci:${__scripter_ci:-generic}" ;;
    *)
      if [ -n "$__scripter_ci" ]; then
        __scripter_r="ci:$__scripter_ci"
      elif ctx::is_tty; then
        __scripter_r=fancy
      else
        __scripter_r=plain
      fi
      ;;
  esac
  __scripter_ret "$__scripter_ret_to" "$__scripter_r"
}
