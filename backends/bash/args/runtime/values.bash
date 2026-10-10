__scripter_args_check() {
  local type=$1 value=$2 name=$3 pattern=$4 re
  shift 4
  case $type in
    int)
      re='^-?[0-9]+$'
      [[ $value =~ $re ]] || __scripter_args_error "invalid value '$value' for '$name': expected an integer"
      ;;
    float)
      re='^-?([0-9]+[.]?[0-9]*|[.][0-9]+)$'
      [[ $value =~ $re ]] || __scripter_args_error "invalid value '$value' for '$name': expected a number"
      ;;
    file)
      [ -f "$value" ] || __scripter_args_error "invalid value '$value' for '$name': no such file"
      ;;
    dir)
      [ -d "$value" ] || __scripter_args_error "invalid value '$value' for '$name': no such directory"
      ;;
    enum)
      __scripter_args_check_enum "$value" "$name" "$@"
      ;;
  esac
  if [ -n "$pattern" ] && ! [[ $value =~ $pattern ]]; then
    __scripter_args_error "invalid value '$value' for '$name': must match $pattern"
  fi
}
__scripter_args_mark_given() {
  printf -v "__scripter_ag_$1" '%s' 1
}
__scripter_args_is_given() {
  local given="__scripter_ag_$1"
  [ -n "${!given:-}" ]
}
# __scripter_args_store <key> <scalar|list> <type> <pattern> <value> <shown> [allowed values...]
__scripter_args_store() {
  local key=$1 shape=$2 type=$3 pattern=$4 value=$5 shown=$6
  shift 6
  __scripter_args_check "$type" "$value" "$shown" "$pattern" "$@"
  if [ "$shape" = list ]; then
    eval "__scripter_al_$key+=(\"\$value\")"
  else
    printf -v "__scripter_av_$key" '%s' "$value"
  fi
  __scripter_args_mark_given "$key"
}
__scripter_args_set_flag() {
  local key=$1 kind=$2 value=$3 current="__scripter_av_$1"
  if [ "$kind" = count ]; then
    if [ -n "$value" ]; then value=$((${!current:-0} + 1)); else value=0; fi
  fi
  printf -v "$current" '%s' "$value"
  __scripter_args_mark_given "$key"
}
