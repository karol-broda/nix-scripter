__scripter_ui_escape() {
  local s=$2
  case $1 in
    github | github-prop)
      s=${s//%/%25}
      s=${s//$'\r'/%0D}
      s=${s//$'\n'/%0A}
      if [ "$1" = github-prop ]; then
        s=${s//:/%3A}
        s=${s//,/%2C}
      fi
      ;;
    azure)
      s=${s//%/%AZP25}
      s=${s//;/%3B}
      s=${s//]/%5D}
      s=${s//$'\r'/%0D}
      s=${s//$'\n'/%0A}
      ;;
    teamcity)
      s=${s//|/||}
      s=${s//\'/|\'}
      s=${s//[/|[}
      s=${s//]/|]}
      s=${s//$'\n'/|n}
      s=${s//$'\r'/|r}
      ;;
  esac
  __scripter_ui_out=$s
}

__scripter_ui_is_github() {
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo) return 0 ;;
    *) return 1 ;;
  esac
}

__scripter_ui_annotation_level() {
  case $1 in
    info | notice) __scripter_ui_out=notice ;;
    warn | warning) __scripter_ui_out=warning ;;
    error) __scripter_ui_out=error ;;
    *) die "ui::annotate: unknown level '$1'" ;;
  esac
}

__scripter_ui_annotate_github() {
  local __scripter_level=$1 __scripter_msg=$2 __scripter_file=$3 __scripter_line=$4 __scripter_props=""
  if [ -n "$__scripter_file" ]; then
    __scripter_ui_escape github-prop "$__scripter_file"
    __scripter_props=" file=$__scripter_ui_out${__scripter_line:+,line=$__scripter_line}"
  fi
  __scripter_ui_escape github "$__scripter_msg"
  printf '::%s%s::%s\n' "$__scripter_level" "$__scripter_props" "$__scripter_ui_out" >&2
}

__scripter_ui_annotate_azure() {
  local __scripter_level=$1 __scripter_msg=$2 __scripter_file=$3 __scripter_line=$4 __scripter_props=""
  if [ "$__scripter_level" = notice ]; then
    ui::info "$__scripter_msg"
    return 0
  fi
  if [ -n "$__scripter_file" ]; then
    __scripter_props=";sourcepath=$__scripter_file${__scripter_line:+;linenumber=$__scripter_line}"
  fi
  __scripter_ui_escape azure "$__scripter_msg"
  printf '##vso[task.logissue type=%s%s]%s\n' "$__scripter_level" "$__scripter_props" "$__scripter_ui_out" >&2
}

__scripter_ui_annotate_message() {
  local __scripter_level=$1 __scripter_msg=$2 __scripter_file=$3 __scripter_line=$4
  if [ -n "$__scripter_file" ]; then
    __scripter_msg="$__scripter_msg ($__scripter_file${__scripter_line:+:$__scripter_line})"
  fi
  case $__scripter_level in
    notice) ui::info "$__scripter_msg" ;;
    warning) ui::warn "$__scripter_msg" ;;
    error) ui::error "$__scripter_msg" ;;
  esac
}

# ui::annotate <notice|warning|error> <message> [file] [line]
ui::annotate() {
  __scripter_ui_init
  __scripter_ui_annotation_level "$1"
  if __scripter_ui_is_github; then
    __scripter_ui_annotate_github "$__scripter_ui_out" "$2" "${3:-}" "${4:-}"
  elif [ "$__scripter_ui_renderer" = ci:azure ]; then
    __scripter_ui_annotate_azure "$__scripter_ui_out" "$2" "${3:-}" "${4:-}"
  else
    __scripter_ui_annotate_message "$__scripter_ui_out" "$2" "${3:-}" "${4:-}"
  fi
}

ui::mask() {
  [ -n "${1:-}" ] || return 0
  __scripter_ui_init
  if __scripter_ui_is_github; then
    __scripter_ui_escape github "$1"
    printf '::add-mask::%s\n' "$__scripter_ui_out" >&2
  elif [ "$__scripter_ui_renderer" = ci:azure ]; then
    __scripter_ui_seq=$((__scripter_ui_seq + 1))
    printf '##vso[task.setvariable variable=SCRIPTER_MASK_%s;issecret=true]%s\n' "$__scripter_ui_seq" "$1" >&2
  fi
}

ui::summary() {
  local __scripter_file=${SCRIPTER_SUMMARY_FILE:-}
  __scripter_ui_init
  if __scripter_ui_is_github; then
    __scripter_file=${GITHUB_STEP_SUMMARY:-$__scripter_file}
  fi
  if [ -n "$__scripter_file" ]; then
    cat >>"$__scripter_file"
  else
    cat >/dev/null
  fi
}
