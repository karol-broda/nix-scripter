__scripter_args_count_given() {
  local key
  __scripter_args_n=0
  for key in "$@"; do
    if __scripter_args_is_given "$key"; then __scripter_args_n=$((__scripter_args_n + 1)); fi
  done
}
# __scripter_args_at_most_one <shown list> <keys...>
__scripter_args_at_most_one() {
  local shown=$1
  shift
  __scripter_args_count_given "$@"
  [ "$__scripter_args_n" -le 1 ] || __scripter_args_error "only one of $shown may be given"
}
__scripter_args_exactly_one() {
  local shown=$1
  shift
  __scripter_args_count_given "$@"
  [ "$__scripter_args_n" -eq 1 ] || __scripter_args_error "exactly one of $shown must be given"
}
# __scripter_args_requires <key> <shown> <required key> <required shown>
__scripter_args_requires() {
  if __scripter_args_is_given "$1" && ! __scripter_args_is_given "$3"; then
    __scripter_args_error "'$2' requires '$4'"
  fi
}
