__scripter_args_is_given() {
  local given="__scripter_ag_$1"
  [ -n "${!given:-}" ]
}

# __scripter_args_limit <le|eq> <shown list> <keys...>
__scripter_args_limit() {
  local op=$1 shown=$2 key given=0
  shift 2
  for key in "$@"; do
    if __scripter_args_is_given "$key"; then given=$((given + 1)); fi
  done
  if [ "$op" = le ] && [ "$given" -gt 1 ]; then
    __scripter_args_error "only one of $shown may be given"
  fi
  if [ "$op" = eq ] && [ "$given" -ne 1 ]; then
    __scripter_args_error "exactly one of $shown must be given"
  fi
}

# __scripter_args_requires <key> <shown> <required key> <required shown>
__scripter_args_requires() {
  if __scripter_args_is_given "$1" && ! __scripter_args_is_given "$3"; then
    __scripter_args_error "'$2' requires '$4'"
  fi
}
