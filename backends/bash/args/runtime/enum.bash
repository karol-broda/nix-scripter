__scripter_args_check_enum() {
  local value=$1 name=$2 allowed
  shift 2
  for allowed in "$@"; do
    if [ "$allowed" = "$value" ]; then return 0; fi
  done
  __scripter_args_suggest "$value" "$@"
  __scripter_args_error "invalid value '$value' for '$name' (possible values: $*)" "$__scripter_args_hint"
}
