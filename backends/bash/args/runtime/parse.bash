# Per level, generated as data:
#   __scripter_args_level_<level>        display|levels whose options apply|help section
#   __scripter_args_options_<level>      long short kind negatable key (one per line)
#   __scripter_args_positionals_<level>  key mode shown
#   __scripter_args_commands_<level>     word level path...
#   __scripter_args_help_<level>, __scripter_args_examples_<level>
# Values go through the setter __scripter_args_set_<level>__<key>.

__scripter_args_table() {
  local table="__scripter_args_${1}_$2"
  __scripter_args_rows=${!table:-}
}

__scripter_args_print_help() {
  local text="__scripter_args_help_$1" examples="__scripter_args_examples_$1" section="__scripter_args_help_section_$2"
  printf '%s' "${!text}"
  if [ -n "$2" ]; then printf '%s' "${!section}"; fi
  printf '%s' "${!examples:-}"
}

# Matches $2 (with $3 as its possible value) against the option tables of the
# levels in $1; sets __scripter_args_used and the bundle remainder
# __scripter_args_rest.
__scripter_args_match() {
  local levels=$1 arg=$2 level long short kind negatable key form value shown
  __scripter_args_used=1 __scripter_args_rest=""
  for level in $levels; do
    __scripter_args_table options "$level"
    while read -r long short kind negatable key; do
      value="" shown=${arg%%=*}
      case $arg in
        "--$long" | "-$short") form=exact ;;
        "--$long="*) form=assign value=${arg#*=} ;;
        "--no-$long") form=negate ;;
        -"$short"?*) form=attached value=${arg#-"$short"} shown=-$short ;;
        *) continue ;;
      esac
      if [ -z "$long" ] || { [ "$form" = negate ] && [ "$negatable" != 1 ]; } ||
        { [ "$form" = attached ] && [ "$short" = - ]; }; then
        continue
      fi
      if [ "$kind" = option ]; then
        if [ "$form" = exact ]; then
          [ "$#" -ge 3 ] || __scripter_args_error "option '$arg' requires a value"
          value=$3 __scripter_args_used=2
        fi
        "__scripter_args_set_${level}__$key" "$value" "$shown"
        return 0
      fi
      case $form in
        assign) __scripter_args_error "option '--$long' does not take a value" ;;
        attached) __scripter_args_rest=-$value value=1 ;;
        negate) value="" ;;
        exact) value=1 ;;
      esac
      __scripter_args_set_flag "$key" "$kind" "$value"
      return 0
    done <<<"$__scripter_args_rows"
  done
  return 1
}

__scripter_args_unknown_option() {
  local levels=$1 arg=$2 level long short kind negatable key
  local -a known=(--help --version)
  [ "${arg#--}" != "$arg" ] || __scripter_args_error "unrecognized option '$arg'"
  for level in $levels; do
    __scripter_args_table options "$level"
    while read -r long short kind negatable key; do
      known+=("--$long")
      if [ "$negatable" = 1 ]; then known+=("--no-$long"); fi
    done <<<"$__scripter_args_rows"
  done
  __scripter_args_suggest "${arg%%=*}" "${known[@]}"
  __scripter_args_error "unrecognized option '$arg'" "$__scripter_args_hint"
}

__scripter_args_assign_positionals() {
  local level=$1 key mode shown i=0 n=${#__scripter_args_pos[@]} missing="" count=0
  __scripter_args_table positionals "$level"
  while read -r key mode shown; do
    [ -n "$key" ] || continue
    while [ "$i" -lt "$n" ]; do
      "__scripter_args_set_${level}__$key" "${__scripter_args_pos[i]}" "$shown"
      i=$((i + 1))
      [ "$mode" = variadic ] || continue 2
    done
    if [ "$mode" = required ]; then
      missing="$missing $shown"
      count=$((count + 1))
    fi
  done <<<"$__scripter_args_rows"
  if [ "$count" -eq 1 ]; then __scripter_args_error "missing required argument$missing"; fi
  if [ "$count" -gt 1 ]; then __scripter_args_error "missing required arguments$missing"; fi
  if [ "$i" -lt "$n" ]; then __scripter_args_error "unexpected argument '${__scripter_args_pos[i]}'"; fi
}

# __scripter_args_parse <level> <args...>
__scripter_args_parse() {
  local level=$1 descriptor="__scripter_args_level_$1" levels section arg commands entered=""
  shift
  IFS='|' read -r __scripter_args_cmd levels section <<<"${!descriptor}"
  __scripter_args_table commands "$level"
  commands=$__scripter_args_rows
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
