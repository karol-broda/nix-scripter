# Per level, generated as data:
#   __scripter_args_level_<level>       display|levels with options that apply|help section
#   __scripter_args_lookup_<level>      case statement: option spelling -> kind and key
#   __scripter_args_longs_<level>       long options, for suggestions
#   __scripter_args_positionals_<level> array of "key mode shown"
#   __scripter_args_help_<level>, __scripter_args_examples_<level>
# Values go through the setter __scripter_args_set_<level>__<key>.
# Lookups are case statements and arrays because `read` loops cost ~30x more.

__scripter_args_print_help() {
  local text="__scripter_args_help_$1" examples="__scripter_args_examples_$1" section="__scripter_args_help_section_$2"
  printf '%s' "${!text}"
  if [ -n "$2" ]; then printf '%s' "${!section}"; fi
  printf '%s' "${!examples:-}"
}

# Matches $2 (with $3 as its possible value) against the options of the
# levels in $1; sets __scripter_args_used and the bundle remainder
# __scripter_args_rest.
__scripter_args_match() {
  local levels=$1 arg=$2 level name form value=""
  __scripter_args_used=1 __scripter_args_rest=""
  case $arg in
    --*=*) name=${arg%%=*} form=assign value=${arg#*=} ;;
    --*) name=$arg form=exact ;;
    -??*) name=${arg:0:2} form=attached value=${arg:2} ;;
    *) name=$arg form=exact ;;
  esac
  for level in $levels; do
    "__scripter_args_lookup_$level" "$name" || continue
    case $__scripter_args_kind:$form in
      option:exact)
        [ "$#" -ge 3 ] || __scripter_args_error "option '$arg' requires a value"
        __scripter_args_used=2
        "__scripter_args_set_${level}__$__scripter_args_key" "$3" "$arg"
        ;;
      option:*) "__scripter_args_set_${level}__$__scripter_args_key" "$value" "$name" ;;
      *:assign) __scripter_args_error "option '$name' does not take a value" ;;
      *:attached)
        __scripter_args_rest=-$value
        __scripter_args_set_flag "$__scripter_args_key" "$__scripter_args_kind" 1
        ;;
      no*) __scripter_args_set_flag "$__scripter_args_key" "${__scripter_args_kind#no}" "" ;;
      *) __scripter_args_set_flag "$__scripter_args_key" "$__scripter_args_kind" 1 ;;
    esac
    return 0
  done
  return 1
}

__scripter_args_unknown_option() {
  local levels=$1 arg=$2 level longs
  local -a known=(--help --version)
  [ "${arg#--}" != "$arg" ] || __scripter_args_error "unrecognized option '$arg'"
  for level in $levels; do
    longs="__scripter_args_longs_$level"
    # shellcheck disable=SC2206
    known+=(${!longs})
  done
  __scripter_args_suggest "${arg%%=*}" "${known[@]}"
  __scripter_args_error "unrecognized option '$arg'" "$__scripter_args_hint"
}

__scripter_args_assign_positionals() {
  local level=$1 table="__scripter_args_positionals_$1[@]" spec i=0 n=${#__scripter_args_pos[@]} missing="" count=0
  local -a row
  for spec in ${!table+"${!table}"}; do
    # shellcheck disable=SC2206
    row=($spec)
    while [ "$i" -lt "$n" ]; do
      "__scripter_args_set_${level}__${row[0]}" "${__scripter_args_pos[i]}" "${row[2]}"
      i=$((i + 1))
      [ "${row[1]}" = variadic ] || continue 2
    done
    if [ "${row[1]}" = required ]; then
      missing="$missing ${row[2]}"
      count=$((count + 1))
    fi
  done
  if [ "$count" -eq 1 ]; then __scripter_args_error "missing required argument$missing"; fi
  if [ "$count" -gt 1 ]; then __scripter_args_error "missing required arguments$missing"; fi
  if [ "$i" -lt "$n" ]; then __scripter_args_error "unexpected argument '${__scripter_args_pos[i]}'"; fi
}

# __scripter_args_parse <level> <args...>
__scripter_args_parse() {
  local level=$1 descriptor="__scripter_args_level_$1" words="__scripter_args_words_$1" levels section arg
  local commands entered=""
  shift
  levels=${!descriptor}
  __scripter_args_cmd=${levels%%|*}
  levels=${levels#*|}
  section=${levels#*|}
  levels=${levels%%|*}
  commands=${!words:-}
  __scripter_args_pos=()
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
          __scripter_args_print_help "$level" "$section"
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
        if [ -n "$commands" ]; then
          __scripter_args_enter_command "$level" "$@"
          entered=1
          break
        fi
        __scripter_args_pos+=("$arg")
        shift
        ;;
    esac
  done
  if [ -z "$commands" ]; then
    __scripter_args_assign_positionals "$level"
  elif [ -z "$entered" ]; then
    __scripter_args_missing_command "$level"
  fi
  if declare -F "__scripter_args_finish_$level" >/dev/null; then "__scripter_args_finish_$level"; fi
}
