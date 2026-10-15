# __scripter_args_flag_from_env <key> <variable> <flag|count>
__scripter_args_flag_from_env() {
  local value=${!2} shown="\$$2"
  if [ "$3" = count ]; then
    __scripter_args_check int "$value" "$shown" ""
  else
    case $value in
      1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy] | [Oo][Nn]) value=1 ;;
      0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo] | [Nn] | [Oo][Ff][Ff]) value="" ;;
      *) __scripter_args_error "invalid boolean '$value' for '$shown'" ;;
    esac
  fi
  __scripter_args_set_flag "$1" flag "$value"
}
