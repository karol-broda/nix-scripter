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

__scripter_args_set_flag() {
  local current="__scripter_av_$1" value=$3
  if [ "$2" = count ]; then
    if [ -n "$value" ]; then value=$((${!current:-0} + 1)); else value=0; fi
  fi
  printf -v "$current" '%s' "$value"
  printf -v "__scripter_ag_$1" '%s' 1
}
