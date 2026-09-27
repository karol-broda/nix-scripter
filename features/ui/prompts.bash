__scripter_ui_ask() {
  printf '%s%s%s%s %s ' "$__scripter_ui_indent" "$__scripter_c_accent" "$__scripter_i_prompt" "$__scripter_c_reset" "$1" >&2
}

__scripter_ui_read_line() {
  IFS= read -r "$@" __scripter_ui_reply || __scripter_ui_reply=""
}

__scripter_ui_take_var_option() {
  __scripter_ui_var=""
  __scripter_ui_shift=0
  if [ "${1:-}" = -v ]; then
    __scripter_ui_var=$2
    __scripter_ui_shift=2
  fi
}

__scripter_ui_normalize_default() {
  case $1 in
    y | Y | yes) __scripter_ui_default=y __scripter_ui_hint='[Y/n]' ;;
    n | N | no) __scripter_ui_default=n __scripter_ui_hint='[y/N]' ;;
    '') __scripter_ui_default="" __scripter_ui_hint='[y/n]' ;;
    *) die "ui::confirm: invalid default '$1' (use y or n)" ;;
  esac
}

# ui::confirm <message> [y|n]
ui::confirm() {
  local __scripter_msg=$1
  __scripter_ui_init
  __scripter_ui_normalize_default "${2:-}"
  if is_true "${SCRIPTER_YES:-}"; then
    ui::debug "$__scripter_msg -> yes (auto-confirmed)"
    return 0
  fi
  if ! ctx::is_interactive; then
    [ -n "$__scripter_ui_default" ] ||
      die "confirmation needed: '$__scripter_msg', but not interactive; $__scripter_ui_yes_hint"
    ui::debug "$__scripter_msg -> $__scripter_ui_default (default, not interactive)"
    [ "$__scripter_ui_default" = y ]
    return
  fi
  while :; do
    __scripter_ui_ask "$__scripter_msg $__scripter_c_dim$__scripter_ui_hint$__scripter_c_reset"
    __scripter_ui_read_line
    case $__scripter_ui_reply in
      [Yy] | [Yy][Ee][Ss]) return 0 ;;
      [Nn] | [Nn][Oo]) return 1 ;;
      '')
        if [ -n "$__scripter_ui_default" ]; then
          [ "$__scripter_ui_default" = y ]
          return
        fi
        ;;
    esac
  done
}

# ui::prompt [-v var] <message> [default]
ui::prompt() {
  __scripter_ui_take_var_option "$@"
  shift "$__scripter_ui_shift"
  local __scripter_var=$__scripter_ui_var __scripter_msg=$1 __scripter_def=${2-}
  __scripter_ui_init
  if ! ctx::is_interactive; then
    [ "$#" -ge 2 ] || die "input needed: '$__scripter_msg', but not interactive and no default"
    __scripter_ret "$__scripter_var" "$__scripter_def"
    return 0
  fi
  __scripter_ui_ask "$__scripter_msg${__scripter_def:+ $__scripter_c_dim($__scripter_def)$__scripter_c_reset}"
  __scripter_ui_read_line
  __scripter_ret "$__scripter_var" "${__scripter_ui_reply:-$__scripter_def}"
}

# ui::secret [-v var] <message>
ui::secret() {
  __scripter_ui_take_var_option "$@"
  shift "$__scripter_ui_shift"
  local __scripter_var=$__scripter_ui_var
  __scripter_ui_init
  ctx::is_interactive || die "secret needed: '$1', but not interactive"
  __scripter_ui_ask "$1"
  __scripter_ui_read_line -s
  printf '\n' >&2
  __scripter_ret "$__scripter_var" "$__scripter_ui_reply"
}
