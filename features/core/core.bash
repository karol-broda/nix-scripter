# --- nix-scripter: core ------------------------------------------------------

__scripter_exit_handlers=()

# on_exit <code>        run a code string on exit
# on_exit <cmd> <arg>…  run a command (arguments kept intact) on exit
# Handlers run last-in first-out, also after INT/TERM.
on_exit() {
  local __scripter_cmd
  if [ "$#" -eq 1 ]; then
    __scripter_cmd=$1
  else
    printf -v __scripter_cmd '%q ' "$@"
  fi
  __scripter_exit_handlers+=("$__scripter_cmd")
}

__scripter_run_exit_handlers() {
  local __scripter_rc=$? __scripter_i
  set +e
  trap - ERR
  for ((__scripter_i = ${#__scripter_exit_handlers[@]} - 1; __scripter_i >= 0; __scripter_i--)); do
    eval "${__scripter_exit_handlers[__scripter_i]}"
  done
  exit "$__scripter_rc"
}

trap __scripter_run_exit_handlers EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# die <message> [exit code]
die() {
  if declare -F ui::error >/dev/null; then
    ui::error "${1:-fatal error}"
  else
    printf '%s: error: %s\n' "$__scripter_name" "${1:-fatal error}" >&2
  fi
  exit "${2:-1}"
}

# need_cmd <cmd>…  fails listing every missing command
need_cmd() {
  local __scripter_c __scripter_missing=
  for __scripter_c in "$@"; do
    command -v "$__scripter_c" >/dev/null 2>&1 || __scripter_missing="$__scripter_missing $__scripter_c"
  done
  if [ -n "$__scripter_missing" ]; then
    die "missing required command(s):$__scripter_missing" 127
  fi
}

# is_true <value>  1/true/yes/y/on, case-insensitive
is_true() {
  case ${1:-} in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy] | [Oo][Nn]) return 0 ;;
    *) return 1 ;;
  esac
}

# mktemp_dir -v <var>  temporary directory, removed on exit
mktemp_dir() {
  if [ "${1:-}" != -v ] || [ -z "${2:-}" ]; then
    die "usage: mktemp_dir -v <variable> (a subshell could not clean up the directory)"
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

# run <cmd>…  honours SCRIPTER_DRY_RUN and prints the command when verbose
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

# Location of a line of the assembled script in the user's source.
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

# core::stacktrace [first frame]  print the call stack to stderr
core::stacktrace() {
  local __scripter_i=${1:-1}
  for ((; __scripter_i < ${#FUNCNAME[@]}; __scripter_i++)); do
    __scripter_location "${BASH_LINENO[__scripter_i - 1]}"
    printf '    at %s (%s)\n' "${FUNCNAME[__scripter_i]}" "$__scripter_loc" >&2
  done
}

__scripter_on_err() {
  local __scripter_rc=$1 __scripter_line=$2 __scripter_cmd=$3
  if [ "${BASH_SUBSHELL:-0}" -gt 0 ]; then
    return 0
  fi
  __scripter_location "$__scripter_line"
  printf '%s: error: command failed with exit code %s\n    %s\n    at %s (%s)\n' \
    "$__scripter_name" "$__scripter_rc" "$__scripter_cmd" "${FUNCNAME[1]:-main}" "$__scripter_loc" >&2
  # frames: 0 core::stacktrace, 1 this handler, 2 failing function, 3+ callers
  core::stacktrace 3
}

if [ -n "$__scripter_core_stacktrace" ]; then
  set -o errtrace
  trap '__scripter_on_err "$?" "$LINENO" "$BASH_COMMAND"' ERR
fi

if is_true "${SCRIPTER_TRACE:-}"; then
  set -x
fi
