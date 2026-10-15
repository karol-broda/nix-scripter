# __scripter_args_commands_<level> is a case statement: word -> "level path...";
# __scripter_args_words_<level> lists every word, __scripter_args_names_<level>
# the canonical ones.
__scripter_args_enter_command() {
  local level=$1 target
  if "__scripter_args_commands_$level" "$2"; then
    target=${__scripter_args_row%% *}
    __scripter_args_command=${__scripter_args_row#* }
    shift 2
    __scripter_args_parse "$target" "$@"
    return 0
  fi
  local words="__scripter_args_words_$level"
  # shellcheck disable=SC2086
  __scripter_args_suggest "$2" ${!words}
  __scripter_args_error "unrecognized command '$2'" "$__scripter_args_hint"
}

__scripter_args_missing_command() {
  local names="__scripter_args_names_$1"
  __scripter_args_error "missing command (one of: ${!names})"
}
