__scripter_args_enter_command() {
  local level=$1 word target path
  local -a words=()
  __scripter_args_table commands "$level"
  while read -r word target path; do
    if [ "$word" = "$2" ]; then
      __scripter_args_command=$path
      shift 2
      __scripter_args_parse "$target" "$@"
      return 0
    fi
    words+=("$word")
  done <<<"$__scripter_args_rows"
  __scripter_args_suggest "$2" "${words[@]}"
  __scripter_args_error "unrecognized command '$2'" "$__scripter_args_hint"
}

__scripter_args_missing_command() {
  local word target path names=""
  __scripter_args_table commands "$1"
  while read -r word target path; do
    if [ "$word" = "${path##* }" ]; then names="$names, $word"; fi
  done <<<"$__scripter_args_rows"
  __scripter_args_error "missing command (one of: ${names#, })"
}
