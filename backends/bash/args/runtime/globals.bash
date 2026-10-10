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
