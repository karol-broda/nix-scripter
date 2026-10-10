# Each level has tables, one entry per line:
#   __scripter_args_options_<level>      long short kind negatable key
#   __scripter_args_positionals_<level>  key mode shown
#   __scripter_args_commands_<level>     word level path...
# Option values are stored by the setter __scripter_args_set_<level>__<key>.

__scripter_args_error() {
  printf '%s: error: %s\n' "$__scripter_name" "$1" >&2
  if [ -n "${2:-}" ]; then printf "\n  tip: did you mean '%s'?\n\n" "$2" >&2; fi
  printf "Try '%s --help' for more information.\n" "$__scripter_args_cmd" >&2
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

__scripter_args_check_enum() {
  local value=$1 name=$2 allowed
  shift 2
  for allowed in "$@"; do
    if [ "$allowed" = "$value" ]; then return 0; fi
  done
  __scripter_args_suggest "$value" "$@"
  __scripter_args_error "invalid value '$value' for '$name' (possible values: $*)" "$__scripter_args_hint"
}

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

__scripter_args_bool() {
  case $1 in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy] | [Oo][Nn]) __scripter_args_b=1 ;;
    "" | 0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo] | [Nn] | [Oo][Ff][Ff]) __scripter_args_b="" ;;
    *) __scripter_args_error "invalid boolean '$1' for '$2'" ;;
  esac
}

__scripter_args_table() {
  local table="__scripter_args_${1}_$2"
  __scripter_args_rows=${!table:-}
}

# Matches $2 (with $3 as its possible value) against the option tables of
# the levels in $1. Sets __scripter_args_used (arguments consumed) and
# __scripter_args_rest (a bundle remainder to parse next).
__scripter_args_match() {
  local levels=$1 arg=$2 level long short kind negatable key setter
  __scripter_args_used=1
  __scripter_args_rest=""
  for level in $levels; do
    __scripter_args_table options "$level"
    while read -r long short kind negatable key; do
      [ -n "$long" ] || continue
      setter="__scripter_args_set_${level}__$key"
      if [ "$kind" = option ]; then
        case $arg in
          "--$long" | "-$short")
            [ "$#" -ge 3 ] || __scripter_args_error "option '$arg' requires a value"
            "$setter" "$3" "$arg"
            __scripter_args_used=2
            return 0
            ;;
          "--$long="*)
            "$setter" "${arg#*=}" "--$long"
            return 0
            ;;
        esac
        if [ "$short" != - ] && [ "${arg#-"$short"}" != "$arg" ] && [ "${arg#--}" = "$arg" ]; then
          "$setter" "${arg#-"$short"}" "-$short"
          return 0
        fi
      else
        case $arg in
          "--$long" | "-$short")
            __scripter_args_set_flag "$key" "$kind" 1
            return 0
            ;;
          "--$long="*)
            __scripter_args_error "option '--$long' does not take a value"
            ;;
          "--no-$long")
            if [ "$negatable" = 1 ]; then
              __scripter_args_set_flag "$key" "$kind" ""
              return 0
            fi
            ;;
        esac
        if [ "$short" != - ] && [ "${arg#-"$short"}" != "$arg" ] && [ "${arg#--}" = "$arg" ]; then
          __scripter_args_set_flag "$key" "$kind" 1
          __scripter_args_rest="-${arg#-"$short"}"
          return 0
        fi
      fi
    done <<<"$__scripter_args_rows"
  done
  return 1
}

__scripter_args_unknown_option() {
  local levels=$1 arg=$2 level long short kind negatable key
  local -a known=()
  if [ "${arg#--}" = "$arg" ]; then
    __scripter_args_error "unrecognized option '$arg'"
  fi
  for level in $levels; do
    __scripter_args_table options "$level"
    while read -r long short kind negatable key; do
      [ -n "$long" ] || continue
      known+=("--$long")
      if [ "$negatable" = 1 ]; then known+=("--no-$long"); fi
    done <<<"$__scripter_args_rows"
  done
  known+=(--help --version)
  __scripter_args_suggest "${arg%%=*}" "${known[@]}"
  __scripter_args_error "unrecognized option '$arg'" "$__scripter_args_hint"
}

__scripter_args_find_command() {
  local level=$1 arg=$2 word target path
  local -a words=()
  __scripter_args_table commands "$level"
  while read -r word target path; do
    if [ "$word" = "$arg" ]; then
      __scripter_args_child=$target
      __scripter_args_command=$path
      return 0
    fi
    words+=("$word")
  done <<<"$__scripter_args_rows"
  __scripter_args_suggest "$arg" "${words[@]}"
  __scripter_args_error "unrecognized command '$arg'" "$__scripter_args_hint"
}

__scripter_args_canonical_commands() {
  local word target path names=""
  __scripter_args_table commands "$1"
  while read -r word target path; do
    if [ "$word" = "${path##* }" ]; then names="$names, $word"; fi
  done <<<"$__scripter_args_rows"
  __scripter_args_out=${names#, }
}

# __scripter_args_parse_level <level> <levels whose options apply> <args...>
__scripter_args_parse_level() {
  local level=$1 levels=$2 arg
  shift 2
  __scripter_args_pos=()
  __scripter_args_table commands "$level"
  local has_commands=$__scripter_args_rows
  while [ "$#" -gt 0 ]; do
    arg=$1
    case $arg in
      --)
        shift
        __scripter_args_pos+=("$@")
        break
        ;;
      -h | --help | -h?*)
        if [ -n "$__scripter_args_help_enabled" ]; then
          "__scripter_args_help_$level"
          exit 0
        fi
        ;;
      --version)
        if [ -n "$__scripter_args_version_enabled" ] && [ "$level" = root ]; then
          printf '%s %s\n' "$__scripter_name" "$__scripter_version"
          exit 0
        fi
        ;;
    esac
    case $arg in
      -?*)
        __scripter_args_match "$levels" "$@" || __scripter_args_unknown_option "$levels" "$arg"
        shift "$__scripter_args_used"
        if [ -n "$__scripter_args_rest" ]; then set -- "$__scripter_args_rest" "$@"; fi
        ;;
      *)
        if [ -n "$has_commands" ]; then
          __scripter_args_find_command "$level" "$arg"
          shift
          "__scripter_args_parse_$__scripter_args_child" "$@"
          return 0
        fi
        __scripter_args_pos+=("$arg")
        shift
        ;;
    esac
  done
  if [ -n "$has_commands" ]; then
    __scripter_args_canonical_commands "$level"
    __scripter_args_error "missing command (one of: $__scripter_args_out)"
  fi
}

__scripter_args_assign_positionals() {
  local level=$1 key mode shown i=0 n=${#__scripter_args_pos[@]} missing="" count=0
  __scripter_args_table positionals "$level"
  while read -r key mode shown; do
    [ -n "$key" ] || continue
    if [ "$mode" = variadic ]; then
      while [ "$i" -lt "$n" ]; do
        "__scripter_args_set_${level}__$key" "${__scripter_args_pos[i]}" "$shown"
        i=$((i + 1))
      done
    elif [ "$i" -lt "$n" ]; then
      "__scripter_args_set_${level}__$key" "${__scripter_args_pos[i]}" "$shown"
      i=$((i + 1))
    elif [ "$mode" = required ]; then
      missing="$missing $shown"
      count=$((count + 1))
    fi
  done <<<"$__scripter_args_rows"
  if [ "$count" -eq 1 ]; then __scripter_args_error "missing required argument$missing"; fi
  if [ "$count" -gt 1 ]; then __scripter_args_error "missing required arguments$missing"; fi
  if [ "$i" -lt "$n" ]; then __scripter_args_error "unexpected argument '${__scripter_args_pos[i]}'"; fi
}

__scripter_args_from_env() {
  local key=$1 env=$2 kind=$3 setter=${4:-} value
  __scripter_args_is_given "$key" && return 0
  value=${!env:-}
  [ -n "$value" ] || return 0
  case $kind in
    option) "$setter" "$value" "\$$env" ;;
    count)
      __scripter_args_check int "$value" "\$$env" ""
      __scripter_args_set_flag "$key" flag "$value"
      ;;
    *)
      __scripter_args_bool "$value" "\$$env"
      __scripter_args_set_flag "$key" flag "$__scripter_args_b"
      ;;
  esac
}

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

__scripter_args_require() {
  __scripter_args_is_given "$1" || __scripter_args_error "missing required option '$2'"
}

__scripter_args_count_given() {
  local key
  __scripter_args_n=0
  for key in "$@"; do
    if __scripter_args_is_given "$key"; then __scripter_args_n=$((__scripter_args_n + 1)); fi
  done
}

# __scripter_args_at_most_one <shown list> <keys...>
__scripter_args_at_most_one() {
  local shown=$1
  shift
  __scripter_args_count_given "$@"
  [ "$__scripter_args_n" -le 1 ] || __scripter_args_error "only one of $shown may be given"
}

__scripter_args_exactly_one() {
  local shown=$1
  shift
  __scripter_args_count_given "$@"
  [ "$__scripter_args_n" -eq 1 ] || __scripter_args_error "exactly one of $shown must be given"
}

# __scripter_args_requires <key> <shown> <required key> <required shown>
__scripter_args_requires() {
  if __scripter_args_is_given "$1" && ! __scripter_args_is_given "$3"; then
    __scripter_args_error "'$2' requires '$4'"
  fi
}

__scripter_args_apply_global() {
  local action=$1 value="__scripter_av_$2"
  value=${!value:-}
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
