__scripter_ui_ci_message() {
  local __scripter_level=$1 __scripter_text=$2 __scripter_status
  case $__scripter_ui_renderer:$__scripter_level in
    ci:github:warn | ci:forgejo:warn | ci:github:error | ci:forgejo:error)
      __scripter_ui_escape github "$__scripter_text"
      printf '::%s::%s\n' "${__scripter_level/warn/warning}" "$__scripter_ui_out" >&2
      ;;
    ci:azure:warn | ci:azure:error)
      __scripter_ui_escape azure "$__scripter_text"
      printf '##vso[task.logissue type=%s]%s\n' "${__scripter_level/warn/warning}" "$__scripter_ui_out" >&2
      ;;
    ci:teamcity:warn | ci:teamcity:error)
      __scripter_ui_escape teamcity "$__scripter_text"
      __scripter_status=WARNING
      if [ "$__scripter_level" = error ]; then __scripter_status=ERROR; fi
      printf "##teamcity[message text='%s' status='%s']\n" "$__scripter_ui_out" "$__scripter_status" >&2
      ;;
    *) return 1 ;;
  esac
}

__scripter_ui_plain_message() {
  local __scripter_label=$1
  if [ "$__scripter_label" = success ]; then __scripter_label=ok; fi
  printf '%s[%s] %s\n' "$__scripter_ui_indent" "$__scripter_label" "$2" >&2
}

__scripter_ui_fancy_message() {
  local __scripter_icon_var=__scripter_i_$1 __scripter_color_var=__scripter_c_$1
  printf '%s%s%s%s %s\n' "$__scripter_ui_indent" "${!__scripter_color_var}" "${!__scripter_icon_var}" \
    "$__scripter_c_reset" "$2" >&2
}

__scripter_ui_msg() {
  __scripter_ui_init
  __scripter_ui_visible "$1" || return 0
  __scripter_ui_ci_message "$1" "$2" && return 0
  if [ "$__scripter_ui_renderer" = plain ]; then
    __scripter_ui_plain_message "$1" "$2"
  else
    __scripter_ui_fancy_message "$1" "$2"
  fi
}

ui::debug() { __scripter_ui_msg debug "$*"; }
ui::info() { __scripter_ui_msg info "$*"; }
ui::success() { __scripter_ui_msg success "$*"; }
ui::warn() { __scripter_ui_msg warn "$*"; }
ui::error() { __scripter_ui_msg error "$*"; }
