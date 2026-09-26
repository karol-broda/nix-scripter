__scripter_args_error() {
  printf '%s: error: %s\n' "$__scripter_name" "$1" >&2
  if [ -n "${3:-}" ]; then printf "\n  tip: did you mean '%s'?\n\n" "$3" >&2; fi
  printf "Try '%s --help' for more information.\n" "$2" >&2
  exit 2
}

__scripter_args_distance() {
  local a=$1 b=$2 i j cost del ins sub
  local -a prev cur
  for ((j = 0; j <= ${#b}; j++)); do prev[j]=$j; done
  for ((i = 1; i <= ${#a}; i++)); do
    cur=("$i")
    for ((j = 1; j <= ${#b}; j++)); do
      if [ "${a:i-1:1}" = "${b:j-1:1}" ]; then cost=0; else cost=1; fi
      del=$((prev[j] + 1))
      ins=$((cur[j - 1] + 1))
      sub=$((prev[j - 1] + cost))
      if [ "$ins" -lt "$del" ]; then del=$ins; fi
      if [ "$sub" -lt "$del" ]; then del=$sub; fi
      cur[j]=$del
    done
    prev=("${cur[@]}")
  done
  __scripter_args_dist=${prev[${#b}]}
}

__scripter_args_suggest() {
  local word=$1 best="" best_dist=3 c
  shift
  for c in "$@"; do
    case $c in "$word"*)
      __scripter_args_hint=$c
      return 0
      ;;
    esac
    __scripter_args_distance "$word" "$c"
    if [ "$__scripter_args_dist" -lt "$best_dist" ]; then
      best=$c
      best_dist=$__scripter_args_dist
    fi
  done
  __scripter_args_hint=$best
}

__scripter_args_require_value() {
  if [ "$1" -lt 2 ]; then
    __scripter_args_error "option '$2' requires a value" "$3"
  fi
}

__scripter_args_check_enum() {
  local value=$1 name=$2 cmd=$3 allowed
  shift 3
  for allowed in "$@"; do
    if [ "$allowed" = "$value" ]; then return 0; fi
  done
  __scripter_args_suggest "$value" "$@"
  __scripter_args_error "invalid value '$value' for '$name' (possible values: $*)" "$cmd" "${__scripter_args_hint:-}"
}

__scripter_args_check() {
  local type=$1 value=$2 name=$3 cmd=$4 pattern=$5 re
  shift 5
  case $type in
    int)
      re='^-?[0-9]+$'
      [[ $value =~ $re ]] || __scripter_args_error "invalid value '$value' for '$name': expected an integer" "$cmd"
      ;;
    float)
      re='^-?([0-9]+[.]?[0-9]*|[.][0-9]+)$'
      [[ $value =~ $re ]] || __scripter_args_error "invalid value '$value' for '$name': expected a number" "$cmd"
      ;;
    file)
      [ -f "$value" ] || __scripter_args_error "invalid value '$value' for '$name': no such file" "$cmd"
      ;;
    dir)
      [ -d "$value" ] || __scripter_args_error "invalid value '$value' for '$name': no such directory" "$cmd"
      ;;
    enum)
      __scripter_args_check_enum "$value" "$name" "$cmd" "$@"
      ;;
  esac
  if [ -n "$pattern" ] && ! [[ $value =~ $pattern ]]; then
    __scripter_args_error "invalid value '$value' for '$name': must match $pattern" "$cmd"
  fi
}

__scripter_args_bool() {
  case $1 in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy] | [Oo][Nn]) __scripter_args_b=1 ;;
    "" | 0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo] | [Nn] | [Oo][Ff][Ff]) __scripter_args_b="" ;;
    *) __scripter_args_error "invalid boolean '$1' for '$2'" "$3" ;;
  esac
}

__scripter_args_count_given() {
  __scripter_args_n=0
  local given
  for given in "$@"; do
    if [ -n "$given" ]; then __scripter_args_n=$((__scripter_args_n + 1)); fi
  done
}

__scripter_args_apply_global() {
  local action=$1 value=$2
  [ -n "$value" ] && [ "$value" != 0 ] || return 0
  case $action in
    verbose) export SCRIPTER_LOG_LEVEL=debug ;;
    quiet) export SCRIPTER_LOG_LEVEL=warn ;;
    yes) export SCRIPTER_YES=1 ;;
    dryRun) export SCRIPTER_DRY_RUN=1 ;;
    color) export SCRIPTER_COLOR="$value" ;;
  esac
}

__scripter_args_missing_implementation() {
  printf '%s: error: command %s has no implementation (define %s)\n' "$__scripter_name" "$1" "$2" >&2
  exit 70
}
