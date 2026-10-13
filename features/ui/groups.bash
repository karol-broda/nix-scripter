__scripter_ui_timestamp() {
  if [ -n "${EPOCHSECONDS:-}" ]; then
    __scripter_ui_out=$EPOCHSECONDS
  else
    __scripter_ui_out=$(date +%s)
  fi
}

__scripter_ui_gitlab_section() {
  __scripter_ui_timestamp
  printf '\e[0Ksection_%s:%s:%s\r\e[0K%s\n' "$1" "$__scripter_ui_out" "$2" "${3:-}" >&2
}

__scripter_ui_group_open() {
  local __scripter_title=$1 __scripter_nested=$2 __scripter_id
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo | ci:azure)
      if [ -n "$__scripter_nested" ]; then
        ui::section "$__scripter_title"
      elif [ "$__scripter_ui_renderer" = ci:azure ]; then
        printf '##[group]%s\n' "$__scripter_title" >&2
      else
        __scripter_ui_escape github "$__scripter_title"
        printf '::group::%s\n' "$__scripter_ui_out" >&2
      fi
      ;;
    ci:gitlab)
      __scripter_ui_seq=$((__scripter_ui_seq + 1))
      __scripter_id="scripter_$$_$__scripter_ui_seq"
      __scripter_ui_group_ids+=("$__scripter_id")
      __scripter_ui_gitlab_section start "${__scripter_id}[collapsed=true]" \
        "$__scripter_c_bold$__scripter_title$__scripter_c_reset"
      ;;
    ci:buildkite) printf -- '--- %s\n' "$__scripter_title" >&2 ;;
    ci:teamcity)
      __scripter_ui_escape teamcity "$__scripter_title"
      printf "##teamcity[blockOpened name='%s']\n" "$__scripter_ui_out" >&2
      ;;
    plain) printf '%s==> %s\n' "$__scripter_ui_indent" "$__scripter_title" >&2 ;;
    ci:*) ui::section "$__scripter_title" ;;
    *)
      ui::section "$__scripter_title"
      __scripter_ui_indent="$__scripter_ui_indent  "
      ;;
  esac
}

__scripter_ui_group_close() {
  local __scripter_title=$1 __scripter_nested=$2 __scripter_last
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo)
      if [ -z "$__scripter_nested" ]; then printf '::endgroup::\n' >&2; fi
      ;;
    ci:azure)
      if [ -z "$__scripter_nested" ]; then printf '##[endgroup]\n' >&2; fi
      ;;
    ci:gitlab)
      __scripter_last=$((${#__scripter_ui_group_ids[@]} - 1))
      __scripter_ui_gitlab_section end "${__scripter_ui_group_ids[__scripter_last]}"
      unset "__scripter_ui_group_ids[$__scripter_last]"
      ;;
    ci:teamcity)
      __scripter_ui_escape teamcity "$__scripter_title"
      printf "##teamcity[blockClosed name='%s']\n" "$__scripter_ui_out" >&2
      ;;
    fancy) __scripter_ui_indent=${__scripter_ui_indent%  } ;;
  esac
}

__scripter_ui_close_open_groups() {
  while [ "${#__scripter_ui_groups[@]}" -gt 0 ]; do
    ui::group_end
  done
}

ui::group_begin() {
  local __scripter_nested=""
  __scripter_ui_init
  if [ -z "${__scripter_ui_groups+x}" ]; then
    __scripter_ui_groups=()
    __scripter_ui_group_ids=()
    on_exit __scripter_ui_close_open_groups
  fi
  if [ "${#__scripter_ui_groups[@]}" -gt 0 ]; then __scripter_nested=1; fi
  __scripter_ui_groups+=("$*")
  __scripter_ui_group_open "$*" "$__scripter_nested"
}

ui::group_end() {
  local __scripter_last __scripter_title __scripter_nested=""
  __scripter_ui_init
  [ -n "${__scripter_ui_groups+x}" ] || return 0
  __scripter_last=$((${#__scripter_ui_groups[@]} - 1))
  [ "$__scripter_last" -ge 0 ] || return 0
  __scripter_title=${__scripter_ui_groups[__scripter_last]}
  unset "__scripter_ui_groups[$__scripter_last]"
  if [ "$__scripter_last" -gt 0 ]; then __scripter_nested=1; fi
  __scripter_ui_group_close "$__scripter_title" "$__scripter_nested"
}

# Runs "$@" in a subshell where errexit applies even if the caller tests the
# result; the status is left in __scripter_ui_rc.
__scripter_ui_run() {
  local __scripter_errexit=""
  case $- in *e*) __scripter_errexit=1 ;; esac
  set +e
  (
    set -e
    "$@"
  )
  __scripter_ui_rc=$?
  if [ -n "$__scripter_errexit" ]; then set -e; fi
}

# ui::group <title> -- <command>...
ui::group() {
  local __scripter_title=$1
  shift
  if [ "${1:-}" = -- ]; then shift; fi
  ui::group_begin "$__scripter_title"
  __scripter_ui_run "$@"
  ui::group_end
  return "$__scripter_ui_rc"
}
