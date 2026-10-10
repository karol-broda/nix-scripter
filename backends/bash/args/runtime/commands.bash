__scripter_args_find_command() {
  local level=$1 arg=$2 word target path
  local -a words=()
  __scripter_args_table commands "$level"
  while read -r word target path; do
    if [ "$word" = "$arg" ]; then
      __scripter_args_child=$target
      __scripter_args_command=$path
      return 0
    fi
    words+=("$word")
  done <<<"$__scripter_args_rows"
  __scripter_args_suggest "$arg" "${words[@]}"
  __scripter_args_error "unrecognized command '$arg'" "$__scripter_args_hint"
}
__scripter_args_canonical_commands() {
  local word target path names=""
  __scripter_args_table commands "$1"
  while read -r word target path; do
    if [ "$word" = "${path##* }" ]; then names="$names, $word"; fi
  done <<<"$__scripter_args_rows"
  __scripter_args_out=${names#, }
}

__scripter_args_enter_command() {
  local level=$1
  __scripter_args_find_command "$level" "$2"
  shift 2
  "__scripter_args_parse_$__scripter_args_child" "$@"
}

__scripter_args_missing_command() {
  __scripter_args_canonical_commands "$1"
  __scripter_args_error "missing command (one of: $__scripter_args_out)"
}
