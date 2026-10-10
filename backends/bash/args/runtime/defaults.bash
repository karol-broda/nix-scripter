__scripter_args_default() {
  local key=$1
  shift
  __scripter_args_is_given "$key" && return 0
  printf -v "__scripter_av_$key" '%s' "$1"
}
__scripter_args_default_list() {
  local key=$1 value
  shift
  __scripter_args_is_given "$key" && return 0
  for value in "$@"; do
    eval "__scripter_al_$key+=(\"\$value\")"
  done
}
