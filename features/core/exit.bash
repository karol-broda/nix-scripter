__scripter_exit_handlers=()

# on_exit <code string> | on_exit <command> <args>...
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
