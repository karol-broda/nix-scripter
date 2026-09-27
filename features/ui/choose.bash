__scripter_ui_menu_draw() {
  local __scripter_i
  for ((__scripter_i = 0; __scripter_i < ${#__scripter_ui_options[@]}; __scripter_i++)); do
    if [ "$__scripter_i" -eq "$__scripter_ui_selected" ]; then
      printf '\r\e[K%s  %s%s %s%s\n' "$__scripter_ui_indent" "$__scripter_c_accent" "$__scripter_i_arrow" \
        "${__scripter_ui_options[__scripter_i]}" "$__scripter_c_reset" >&2
    else
      printf '\r\e[K%s    %s\n' "$__scripter_ui_indent" "${__scripter_ui_options[__scripter_i]}" >&2
    fi
  done
}

__scripter_ui_menu_read_key() {
  local __scripter_key __scripter_rest
  IFS= read -rsn1 __scripter_key || __scripter_key=""
  case $__scripter_key in
    $'\e')
      IFS= read -rsn2 -t 1 __scripter_rest || __scripter_rest=""
      case $__scripter_rest in
        '[A') __scripter_ui_key=up ;;
        '[B') __scripter_ui_key=down ;;
        *) __scripter_ui_key=none ;;
      esac
      ;;
    k) __scripter_ui_key=up ;;
    j) __scripter_ui_key=down ;;
    '') __scripter_ui_key=enter ;;
    *) __scripter_ui_key=$__scripter_key ;;
  esac
}

__scripter_ui_menu_apply_key() {
  local __scripter_n=${#__scripter_ui_options[@]}
  case $__scripter_ui_key in
    up) __scripter_ui_selected=$(((__scripter_ui_selected + __scripter_n - 1) % __scripter_n)) ;;
    down) __scripter_ui_selected=$(((__scripter_ui_selected + 1) % __scripter_n)) ;;
    [1-9])
      if [ "$__scripter_ui_key" -le "$__scripter_n" ]; then __scripter_ui_selected=$((__scripter_ui_key - 1)); fi
      ;;
  esac
}

__scripter_ui_menu_collapse() {
  printf '\e[%dA\r\e[J\e[1A\r\e[K' "${#__scripter_ui_options[@]}" >&2
  __scripter_ui_show_cursor
  __scripter_ui_ask "$1"
  printf '%s%s%s\n' "$__scripter_c_accent" "${__scripter_ui_options[__scripter_ui_selected]}" "$__scripter_c_reset" >&2
}

__scripter_ui_menu_select_default() {
  local __scripter_i
  __scripter_ui_selected=0
  for ((__scripter_i = 0; __scripter_i < ${#__scripter_ui_options[@]}; __scripter_i++)); do
    if [ "${__scripter_ui_options[__scripter_i]}" = "$1" ]; then __scripter_ui_selected=$__scripter_i; fi
  done
}

# ui::choose [-v var] [--default <option>] <message> <option>...
ui::choose() {
  local __scripter_var="" __scripter_def="" __scripter_msg
  while [ "$#" -gt 0 ]; do
    case $1 in
      -v) __scripter_var=$2 ;;
      --default) __scripter_def=$2 ;;
      *) break ;;
    esac
    shift 2
  done
  __scripter_msg=$1
  shift
  [ "$#" -gt 0 ] || die "ui::choose: no options given"
  __scripter_ui_init
  if ! ctx::is_interactive; then
    [ -n "$__scripter_def" ] || die "choice needed: '$__scripter_msg', but not interactive and no --default"
    __scripter_ret "$__scripter_var" "$__scripter_def"
    return 0
  fi
  __scripter_ui_options=("$@")
  __scripter_ui_menu_select_default "$__scripter_def"
  __scripter_ui_ask "$__scripter_msg"
  printf '\n' >&2
  __scripter_ui_hide_cursor
  while :; do
    __scripter_ui_menu_draw
    __scripter_ui_menu_read_key
    [ "$__scripter_ui_key" != enter ] || break
    __scripter_ui_menu_apply_key
    printf '\e[%dA' "${#__scripter_ui_options[@]}" >&2
  done
  __scripter_ui_menu_collapse "$__scripter_msg"
  __scripter_ret "$__scripter_var" "${__scripter_ui_options[__scripter_ui_selected]}"
}
