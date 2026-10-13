__scripter_ui_load_colors() {
  __scripter_c_reset=$'\e[0m' __scripter_c_bold=$'\e[1m' __scripter_c_dim=$'\e[2m'
  __scripter_c_debug=$__scripter_ui_theme_debug __scripter_c_info=$__scripter_ui_theme_info
  __scripter_c_success=$__scripter_ui_theme_success __scripter_c_warn=$__scripter_ui_theme_warn
  __scripter_c_error=$__scripter_ui_theme_error __scripter_c_accent=$__scripter_ui_theme_accent
}

__scripter_ui_clear_colors() {
  __scripter_c_reset="" __scripter_c_bold="" __scripter_c_dim=""
  __scripter_c_debug="" __scripter_c_info="" __scripter_c_success=""
  __scripter_c_warn="" __scripter_c_error="" __scripter_c_accent=""
}

__scripter_ui_icons_ascii() {
  __scripter_i_debug='.' __scripter_i_info='*' __scripter_i_success='+'
  __scripter_i_warn='!' __scripter_i_error='x' __scripter_i_bullet='-'
  __scripter_i_arrow='>' __scripter_i_prompt='?' __scripter_i_rule='-'
  __scripter_i_bar_full='#' __scripter_i_bar_empty='.'
  __scripter_ui_frames=('|' '/' '-' "\\")
}

__scripter_ui_icons_unicode() {
  __scripter_i_debug='·' __scripter_i_info='ℹ' __scripter_i_success='✔'
  __scripter_i_warn='⚠' __scripter_i_error='✖' __scripter_i_bullet='•'
  __scripter_i_arrow='›' __scripter_i_prompt='?' __scripter_i_rule='─'
  __scripter_i_bar_full='█' __scripter_i_bar_empty='░'
  __scripter_ui_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
}

__scripter_ui_icons_nerdfont() {
  __scripter_ui_icons_unicode
  __scripter_i_debug='' __scripter_i_info='' __scripter_i_success=''
  __scripter_i_warn='' __scripter_i_error=''
  __scripter_i_arrow='' __scripter_i_prompt=''
}

__scripter_ui_load_icons() {
  case ${SCRIPTER_ICONS:-$__scripter_ui_icons_default} in
    unicode) __scripter_ui_icons_unicode ;;
    nerdfont) __scripter_ui_icons_nerdfont ;;
    *) __scripter_ui_icons_ascii ;;
  esac
}

__scripter_ui_init() {
  if [ -n "${__scripter_ui_ready:-}" ]; then return 0; fi
  __scripter_ui_ready=1
  __scripter_ui_renderer=plain
  ctx::renderer -v __scripter_ui_renderer
  __scripter_ui_indent=""
  __scripter_ui_seq=0
  __scripter_ui_cursor_hidden=""
  __scripter_ui_spin_pid=""
  __scripter_ui_progress_last=""
  if ctx::color; then __scripter_ui_load_colors; else __scripter_ui_clear_colors; fi
  __scripter_ui_load_icons
  on_exit __scripter_ui_cleanup
}

__scripter_ui_hide_cursor() {
  printf '\e[?25l' >&2
  __scripter_ui_cursor_hidden=1
}

__scripter_ui_show_cursor() {
  printf '\e[?25h' >&2
  __scripter_ui_cursor_hidden=""
}

__scripter_ui_cleanup() {
  if [ -n "${__scripter_ui_spin_pid:-}" ]; then
    kill "$__scripter_ui_spin_pid" 2>/dev/null || true
  fi
  if [ -n "${__scripter_ui_cursor_hidden:-}" ]; then
    __scripter_ui_show_cursor
  fi
}

__scripter_ui_level_rank() {
  case $1 in
    debug | trace) __scripter_ui_rank=10 ;;
    warn | warning) __scripter_ui_rank=30 ;;
    error) __scripter_ui_rank=40 ;;
    *) __scripter_ui_rank=20 ;;
  esac
}

__scripter_ui_visible() {
  local __scripter_wanted
  __scripter_ui_level_rank "$1"
  __scripter_wanted=$__scripter_ui_rank
  __scripter_ui_level_rank "${SCRIPTER_LOG_LEVEL:-info}"
  [ "$__scripter_wanted" -ge "$__scripter_ui_rank" ]
}

__scripter_ui_repeat() {
  local __scripter_n=$2
  __scripter_ui_out=""
  while [ "$__scripter_n" -gt 0 ]; do
    __scripter_ui_out=$__scripter_ui_out$1
    __scripter_n=$((__scripter_n - 1))
  done
}
