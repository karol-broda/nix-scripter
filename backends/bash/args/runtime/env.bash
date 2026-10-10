__scripter_args_bool() {
  case $1 in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy] | [Oo][Nn]) __scripter_args_b=1 ;;
    "" | 0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo] | [Nn] | [Oo][Ff][Ff]) __scripter_args_b="" ;;
    *) __scripter_args_error "invalid boolean '$1' for '$2'" ;;
  esac
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
