# Each level has tables, one entry per line:
#   __scripter_args_options_<level>      long short kind negatable key
#   __scripter_args_positionals_<level>  key mode shown
#   __scripter_args_commands_<level>     word level path...
# Option values are stored by the setter __scripter_args_set_<level>__<key>.

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
          __scripter_args_enter_command "$level" "$@"
          return 0
        fi
        __scripter_args_pos+=("$arg")
        shift
        ;;
    esac
  done
  if [ -n "$has_commands" ]; then
    __scripter_args_missing_command "$level"
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
