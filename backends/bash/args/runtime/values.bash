__scripter_args_check() {
  local type=$1 value=$2 name=$3 pattern=$4 re="" expected=""
  shift 4
  case $type in
    int) re='^-?[0-9]+$' expected="an integer" ;;
    float) re='^-?([0-9]+[.]?[0-9]*|[.][0-9]+)$' expected="a number" ;;
    file) [ -f "$value" ] || expected="file" ;;
    dir) [ -d "$value" ] || expected="directory" ;;
    enum) __scripter_args_check_enum "$value" "$name" "$@" ;;
  esac
  if [ -n "$re" ] && ! [[ $value =~ $re ]]; then
    __scripter_args_error "invalid value '$value' for '$name': expected $expected"
  elif [ -z "$re" ] && [ -n "$expected" ]; then
    __scripter_args_error "invalid value '$value' for '$name': no such $expected"
  fi
  if [ -n "$pattern" ] && ! [[ $value =~ $pattern ]]; then
    __scripter_args_error "invalid value '$value' for '$name': must match $pattern"
  fi
}

__scripter_args_is_given() {
  local given="__scripter_ag_$1"
  [ -n "${!given:-}" ]
}

__scripter_args_assign() {
  if [ "$2" = list ]; then
    eval "__scripter_al_$1+=(\"\$3\")"
  else
    printf -v "__scripter_av_$1" '%s' "$3"
  fi
}

# __scripter_args_store <key> <scalar|list> <type> <pattern> <value> <shown> [allowed values...]
__scripter_args_store() {
  local key=$1 shape=$2 type=$3 pattern=$4 value=$5 shown=$6
  shift 6
  __scripter_args_check "$type" "$value" "$shown" "$pattern" "$@"
  __scripter_args_assign "$key" "$shape" "$value"
  printf -v "__scripter_ag_$key" '%s' 1
}

__scripter_args_set_flag() {
  local key=$1 value=$3 current="__scripter_av_$1"
  if [ "$2" = count ]; then
    if [ -n "$value" ]; then value=$((${!current:-0} + 1)); else value=0; fi
  fi
  __scripter_args_assign "$key" scalar "$value"
  printf -v "__scripter_ag_$key" '%s' 1
}
