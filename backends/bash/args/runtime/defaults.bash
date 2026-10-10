# __scripter_args_default <key> <scalar|list> <values...>
__scripter_args_default() {
  local key=$1 shape=$2 value
  shift 2
  __scripter_args_is_given "$key" && return 0
  for value in "$@"; do
    __scripter_args_assign "$key" "$shape" "$value"
  done
}
