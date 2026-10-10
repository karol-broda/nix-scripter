__scripter_args_missing_implementation() {
  printf '%s: error: command %s has no implementation (define %s)\n' "$__scripter_name" "$1" "$2" >&2
  exit 70
}
