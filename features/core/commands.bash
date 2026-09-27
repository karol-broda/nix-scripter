die() {
  if declare -F ui::error >/dev/null; then
    ui::error "${1:-fatal error}"
  else
    printf '%s: error: %s\n' "$__scripter_name" "${1:-fatal error}" >&2
  fi
  exit "${2:-1}"
}

need_cmd() {
  local __scripter_c __scripter_missing=""
  for __scripter_c in "$@"; do
    command -v "$__scripter_c" >/dev/null 2>&1 || __scripter_missing="$__scripter_missing $__scripter_c"
  done
  if [ -n "$__scripter_missing" ]; then
    die "missing required command(s):$__scripter_missing" 127
  fi
}

is_true() {
  case ${1:-} in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy] | [Oo][Nn]) return 0 ;;
    *) return 1 ;;
  esac
}

# Only `-v <var>` exists: a subshell could not register the cleanup.
mktemp_dir() {
  if [ "${1:-}" != -v ] || [ -z "${2:-}" ]; then
    die "usage: mktemp_dir -v <variable>"
  fi
  need_cmd mktemp rm
  local __scripter_dir
  __scripter_dir=$(mktemp -d "${TMPDIR:-/tmp}/${__scripter_name}.XXXXXX") ||
    die "could not create a temporary directory"
  on_exit rm -rf -- "$__scripter_dir"
  printf -v "$2" '%s' "$__scripter_dir"
}

__scripter_show_cmd() {
  local __scripter_prefix=$1 __scripter_q
  shift
  printf -v __scripter_q '%q ' "$@"
  if declare -F ui::info >/dev/null; then
    ui::info "$__scripter_prefix ${__scripter_q% }"
  else
    printf '%s %s\n' "$__scripter_prefix" "${__scripter_q% }" >&2
  fi
}

run() {
  if is_true "${SCRIPTER_DRY_RUN:-}"; then
    __scripter_show_cmd '[dry-run]' "$@"
    return 0
  fi
  if [ "${SCRIPTER_LOG_LEVEL:-info}" = debug ]; then
    __scripter_show_cmd '+' "$@"
  fi
  "$@"
}

if is_true "${SCRIPTER_TRACE:-}"; then
  set -x
fi
