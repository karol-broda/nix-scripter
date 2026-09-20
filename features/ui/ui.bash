# --- nix-scripter: ui --------------------------------------------------------
# All output goes to stderr. Renderers: fancy (terminal), plain (pipes, logs),
# ci:<provider> (native groups, annotations, masking, job summaries).

__scripter_ui_sgr() {
  case $1 in
    bold) __scripter_ui_esc=$'\e[1m' ;;
    dim) __scripter_ui_esc=$'\e[2m' ;;
    black) __scripter_ui_esc=$'\e[30m' ;;
    red) __scripter_ui_esc=$'\e[31m' ;;
    green) __scripter_ui_esc=$'\e[32m' ;;
    yellow) __scripter_ui_esc=$'\e[33m' ;;
    blue) __scripter_ui_esc=$'\e[34m' ;;
    magenta) __scripter_ui_esc=$'\e[35m' ;;
    cyan) __scripter_ui_esc=$'\e[36m' ;;
    white) __scripter_ui_esc=$'\e[37m' ;;
    gray) __scripter_ui_esc=$'\e[90m' ;;
    bright-red) __scripter_ui_esc=$'\e[91m' ;;
    bright-green) __scripter_ui_esc=$'\e[92m' ;;
    bright-yellow) __scripter_ui_esc=$'\e[93m' ;;
    bright-blue) __scripter_ui_esc=$'\e[94m' ;;
    bright-magenta) __scripter_ui_esc=$'\e[95m' ;;
    bright-cyan) __scripter_ui_esc=$'\e[96m' ;;
    *) __scripter_ui_esc='' ;;
  esac
}

__scripter_ui_init() {
  if [ -n "${__scripter_ui_ready:-}" ]; then return 0; fi
  __scripter_ui_ready=1
  __scripter_ui_renderer=plain
  ctx::renderer -v __scripter_ui_renderer
  __scripter_ui_indent=
  __scripter_ui_groups=()
  __scripter_ui_group_ids=()
  __scripter_ui_group_seq=0
  __scripter_ui_cursor_hidden=
  __scripter_ui_spin_pid=
  __scripter_ui_progress_last=

  local __scripter_role __scripter_name_var
  if ctx::color; then
    __scripter_c_reset=$'\e[0m'
    __scripter_c_bold=$'\e[1m'
    __scripter_c_dim=$'\e[2m'
    for __scripter_role in debug info success warn error accent; do
      __scripter_name_var=__scripter_ui_theme_$__scripter_role
      __scripter_ui_sgr "${!__scripter_name_var}"
      printf -v "__scripter_c_$__scripter_role" '%s' "$__scripter_ui_esc"
    done
  else
    __scripter_c_reset='' __scripter_c_bold='' __scripter_c_dim=
    __scripter_c_debug='' __scripter_c_info='' __scripter_c_success=
    __scripter_c_warn='' __scripter_c_error='' __scripter_c_accent=
  fi

  case ${SCRIPTER_ICONS:-$__scripter_ui_icons_default} in
    unicode)
      __scripter_i_debug='·' __scripter_i_info='ℹ' __scripter_i_success='✔'
      __scripter_i_warn='⚠' __scripter_i_error='✖' __scripter_i_bullet='•'
      __scripter_i_arrow='›' __scripter_i_prompt='?' __scripter_i_rule='─'
      __scripter_i_bar_full='█' __scripter_i_bar_empty='░'
      __scripter_ui_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
      ;;
    nerdfont)
      __scripter_i_debug='' __scripter_i_info='' __scripter_i_success=''
      __scripter_i_warn='' __scripter_i_error='' __scripter_i_bullet='•'
      __scripter_i_arrow='' __scripter_i_prompt='' __scripter_i_rule='─'
      __scripter_i_bar_full='█' __scripter_i_bar_empty='░'
      __scripter_ui_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
      ;;
    *)
      __scripter_i_debug='.' __scripter_i_info='*' __scripter_i_success='+'
      __scripter_i_warn='!' __scripter_i_error='x' __scripter_i_bullet='-'
      __scripter_i_arrow='>' __scripter_i_prompt='?' __scripter_i_rule='-'
      __scripter_i_bar_full='#' __scripter_i_bar_empty='.'
      __scripter_ui_frames=('|' '/' '-' "\\")
      ;;
  esac

  on_exit __scripter_ui_cleanup
}

__scripter_ui_cleanup() {
  if [ -n "${__scripter_ui_spin_pid:-}" ]; then
    kill "$__scripter_ui_spin_pid" 2>/dev/null || true
  fi
  if [ -n "${__scripter_ui_cursor_hidden:-}" ]; then
    printf '\e[?25h' >&2
  fi
  while [ "${#__scripter_ui_groups[@]}" -gt 0 ]; do
    ui::group_end
  done
}

# status 0 when a message of level $1 is shown at the current log level
__scripter_ui_visible() {
  local __scripter_want __scripter_have
  case $1 in
    debug) __scripter_want=10 ;;
    warn) __scripter_want=30 ;;
    error) __scripter_want=40 ;;
    *) __scripter_want=20 ;;
  esac
  case ${SCRIPTER_LOG_LEVEL:-info} in
    debug | trace) __scripter_have=10 ;;
    warn | warning) __scripter_have=30 ;;
    error) __scripter_have=40 ;;
    *) __scripter_have=20 ;;
  esac
  [ "$__scripter_want" -ge "$__scripter_have" ]
}

# Escaping for CI workflow commands, result in __scripter_ui_out.
__scripter_ui_escape() {
  local s=$2
  case $1 in
    github)
      s=${s//%/%25}
      s=${s//$'\r'/%0D}
      s=${s//$'\n'/%0A}
      ;;
    github-prop)
      s=${s//%/%25}
      s=${s//$'\r'/%0D}
      s=${s//$'\n'/%0A}
      s=${s//:/%3A}
      s=${s//,/%2C}
      ;;
    azure)
      s=${s//%/%AZP25}
      s=${s//;/%3B}
      s=${s//]/%5D}
      s=${s//$'\r'/%0D}
      s=${s//$'\n'/%0A}
      ;;
    teamcity)
      s=${s//|/||}
      s=${s//\'/|\'}
      s=${s//[/|[}
      s=${s//]/|]}
      s=${s//$'\n'/|n}
      s=${s//$'\r'/|r}
      ;;
  esac
  __scripter_ui_out=$s
}

__scripter_ui_msg() {
  local __scripter_level=$1 __scripter_text=$2 __scripter_icon __scripter_color __scripter_label
  __scripter_ui_init
  __scripter_ui_visible "$__scripter_level" || return 0

  case $__scripter_ui_renderer:$__scripter_level in
    ci:github:warn | ci:forgejo:warn)
      __scripter_ui_escape github "$__scripter_text"
      printf '::warning::%s\n' "$__scripter_ui_out" >&2
      return 0
      ;;
    ci:github:error | ci:forgejo:error)
      __scripter_ui_escape github "$__scripter_text"
      printf '::error::%s\n' "$__scripter_ui_out" >&2
      return 0
      ;;
    ci:azure:warn | ci:azure:error)
      __scripter_ui_escape azure "$__scripter_text"
      printf '##vso[task.logissue type=%s]%s\n' "${__scripter_level/warn/warning}" "$__scripter_ui_out" >&2
      return 0
      ;;
    ci:teamcity:warn | ci:teamcity:error)
      __scripter_ui_escape teamcity "$__scripter_text"
      __scripter_label=WARNING
      if [ "$__scripter_level" = error ]; then __scripter_label=ERROR; fi
      printf "##teamcity[message text='%s' status='%s']\n" "$__scripter_ui_out" "$__scripter_label" >&2
      return 0
      ;;
    plain:*)
      case $__scripter_level in
        success) __scripter_label=ok ;;
        *) __scripter_label=$__scripter_level ;;
      esac
      printf '%s[%s] %s\n' "$__scripter_ui_indent" "$__scripter_label" "$__scripter_text" >&2
      return 0
      ;;
  esac

  case $__scripter_level in
    debug) __scripter_icon=$__scripter_i_debug __scripter_color=$__scripter_c_debug ;;
    success) __scripter_icon=$__scripter_i_success __scripter_color=$__scripter_c_success ;;
    warn) __scripter_icon=$__scripter_i_warn __scripter_color=$__scripter_c_warn ;;
    error) __scripter_icon=$__scripter_i_error __scripter_color=$__scripter_c_error ;;
    *) __scripter_icon=$__scripter_i_info __scripter_color=$__scripter_c_info ;;
  esac
  printf '%s%s%s%s %s\n' "$__scripter_ui_indent" "$__scripter_color" "$__scripter_icon" "$__scripter_c_reset" "$__scripter_text" >&2
}

ui::debug() { __scripter_ui_msg debug "$*"; }
ui::info() { __scripter_ui_msg info "$*"; }
ui::success() { __scripter_ui_msg success "$*"; }
ui::warn() { __scripter_ui_msg warn "$*"; }
ui::error() { __scripter_ui_msg error "$*"; }

__scripter_ui_repeat() {
  local __scripter_n=$2
  __scripter_ui_out=
  while [ "$__scripter_n" -gt 0 ]; do
    __scripter_ui_out=$__scripter_ui_out$1
    __scripter_n=$((__scripter_n - 1))
  done
}

ui::header() {
  local __scripter_title="$*"
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  if [ "$__scripter_ui_renderer" = plain ]; then
    printf '%s== %s ==\n' "$__scripter_ui_indent" "$__scripter_title" >&2
    return 0
  fi
  __scripter_ui_repeat "$__scripter_i_rule" "${#__scripter_title}"
  printf '%s%s%s%s%s\n%s%s%s%s\n' \
    "$__scripter_ui_indent" "$__scripter_c_bold" "$__scripter_c_accent" "$__scripter_title" "$__scripter_c_reset" \
    "$__scripter_ui_indent" "$__scripter_c_dim" "$__scripter_ui_out" "$__scripter_c_reset" >&2
}

ui::section() {
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  if [ "$__scripter_ui_renderer" = plain ]; then
    printf '%s-- %s\n' "$__scripter_ui_indent" "$*" >&2
    return 0
  fi
  printf '%s%s%s %s%s\n' "$__scripter_ui_indent" "$__scripter_c_bold" "$__scripter_i_arrow" "$*" "$__scripter_c_reset" >&2
}

# ui::kv <key> <value>
ui::kv() {
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  printf '%s%s%-*s%s %s\n' "$__scripter_ui_indent" "$__scripter_c_dim" "$__scripter_ui_kv_width" "$1" \
    "$__scripter_c_reset" "${2:-}" >&2
}

# ui::list <item>…
ui::list() {
  local __scripter_item
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  for __scripter_item in "$@"; do
    printf '%s  %s %s\n' "$__scripter_ui_indent" "$__scripter_i_bullet" "$__scripter_item" >&2
  done
}

__scripter_ui_ask() {
  printf '%s%s%s%s %s ' "$__scripter_ui_indent" "$__scripter_c_accent" "$__scripter_i_prompt" "$__scripter_c_reset" "$1" >&2
}

# ui::confirm <message> [default: y|n]
ui::confirm() {
  local __scripter_msg=$1 __scripter_def=${2:-} __scripter_hint __scripter_reply
  __scripter_ui_init
  if is_true "${SCRIPTER_YES:-}"; then
    ui::debug "$__scripter_msg -> yes (auto-confirmed)"
    return 0
  fi
  case $__scripter_def in
    y | Y | yes) __scripter_def=y __scripter_hint='[Y/n]' ;;
    n | N | no) __scripter_def=n __scripter_hint='[y/N]' ;;
    '') __scripter_hint='[y/n]' ;;
    *) die "ui::confirm: invalid default '$__scripter_def' (use y or n)" ;;
  esac
  if ! ctx::is_interactive; then
    if [ -z "$__scripter_def" ]; then
      die "confirmation needed: '$__scripter_msg' — not interactive; $__scripter_ui_yes_hint"
    fi
    ui::debug "$__scripter_msg -> $__scripter_def (default, not interactive)"
    [ "$__scripter_def" = y ]
    return
  fi
  while :; do
    __scripter_ui_ask "$__scripter_msg $__scripter_c_dim$__scripter_hint$__scripter_c_reset"
    IFS='' read -r __scripter_reply || __scripter_reply=
    case $__scripter_reply in
      [Yy] | [Yy][Ee][Ss]) return 0 ;;
      [Nn] | [Nn][Oo]) return 1 ;;
      '')
        if [ -n "$__scripter_def" ]; then
          [ "$__scripter_def" = y ]
          return
        fi
        ;;
    esac
  done
}

# ui::prompt [-v var] <message> [default]
ui::prompt() {
  local __scripter_var='' __scripter_reply
  if [ "${1:-}" = -v ]; then
    __scripter_var=$2
    shift 2
  fi
  local __scripter_msg=$1 __scripter_def=${2-}
  __scripter_ui_init
  if ! ctx::is_interactive; then
    if [ "$#" -lt 2 ]; then
      die "input needed: '$__scripter_msg' — not interactive and no default"
    fi
    __scripter_ret "$__scripter_var" "$__scripter_def"
    return 0
  fi
  if [ -n "$__scripter_def" ]; then
    __scripter_ui_ask "$__scripter_msg $__scripter_c_dim($__scripter_def)$__scripter_c_reset"
  else
    __scripter_ui_ask "$__scripter_msg"
  fi
  IFS='' read -r __scripter_reply || __scripter_reply=
  __scripter_ret "$__scripter_var" "${__scripter_reply:-$__scripter_def}"
}

# ui::secret [-v var] <message>
ui::secret() {
  local __scripter_var='' __scripter_reply
  if [ "${1:-}" = -v ]; then
    __scripter_var=$2
    shift 2
  fi
  __scripter_ui_init
  if ! ctx::is_interactive; then
    die "secret needed: '$1' — not interactive"
  fi
  __scripter_ui_ask "$1"
  IFS='' read -rs __scripter_reply || __scripter_reply=
  printf '\n' >&2
  __scripter_ret "$__scripter_var" "$__scripter_reply"
}

# ui::choose [-v var] [--default <option>] <message> <option>…
ui::choose() {
  local __scripter_var='' __scripter_def=
  while [ "$#" -gt 0 ]; do
    case $1 in
      -v)
        __scripter_var=$2
        shift 2
        ;;
      --default)
        __scripter_def=$2
        shift 2
        ;;
      *) break ;;
    esac
  done
  local __scripter_msg=$1
  shift
  [ "$#" -gt 0 ] || die "ui::choose: no options given"
  __scripter_ui_init
  if ! ctx::is_interactive; then
    if [ -z "$__scripter_def" ]; then
      die "choice needed: '$__scripter_msg' — not interactive and no --default"
    fi
    __scripter_ret "$__scripter_var" "$__scripter_def"
    return 0
  fi

  local -a __scripter_opts=("$@")
  local __scripter_n=$# __scripter_sel=0 __scripter_i __scripter_key __scripter_rest
  for ((__scripter_i = 0; __scripter_i < __scripter_n; __scripter_i++)); do
    if [ "${__scripter_opts[__scripter_i]}" = "$__scripter_def" ]; then __scripter_sel=$__scripter_i; fi
  done

  __scripter_ui_ask "$__scripter_msg"
  printf '\n\e[?25l' >&2
  __scripter_ui_cursor_hidden=1
  while :; do
    for ((__scripter_i = 0; __scripter_i < __scripter_n; __scripter_i++)); do
      if [ "$__scripter_i" -eq "$__scripter_sel" ]; then
        printf '\r\e[K%s  %s%s %s%s\n' "$__scripter_ui_indent" "$__scripter_c_accent" "$__scripter_i_arrow" \
          "${__scripter_opts[__scripter_i]}" "$__scripter_c_reset" >&2
      else
        printf '\r\e[K%s    %s\n' "$__scripter_ui_indent" "${__scripter_opts[__scripter_i]}" >&2
      fi
    done
    IFS='' read -rsn1 __scripter_key || break
    case $__scripter_key in
      $'\e')
        IFS='' read -rsn2 -t 1 __scripter_rest || __scripter_rest=
        case $__scripter_rest in
          '[A') __scripter_key=up ;;
          '[B') __scripter_key=down ;;
        esac
        ;;
      k) __scripter_key=up ;;
      j) __scripter_key=down ;;
      '') break ;;
      [1-9])
        if [ "$__scripter_key" -le "$__scripter_n" ]; then __scripter_sel=$((__scripter_key - 1)); fi
        ;;
    esac
    case $__scripter_key in
      up) __scripter_sel=$(((__scripter_sel + __scripter_n - 1) % __scripter_n)) ;;
      down) __scripter_sel=$(((__scripter_sel + 1) % __scripter_n)) ;;
    esac
    printf '\e[%dA' "$__scripter_n" >&2
  done
  # collapse the menu into the prompt line
  printf '\e[%dA\r\e[J\e[1A\r\e[K\e[?25h' "$__scripter_n" >&2
  __scripter_ui_cursor_hidden=
  __scripter_ui_ask "$__scripter_msg"
  printf '%s%s%s\n' "$__scripter_c_accent" "${__scripter_opts[__scripter_sel]}" "$__scripter_c_reset" >&2
  __scripter_ret "$__scripter_var" "${__scripter_opts[__scripter_sel]}"
}

__scripter_ui_timestamp() {
  if [ -n "${EPOCHSECONDS:-}" ]; then
    __scripter_ui_out=$EPOCHSECONDS
  else
    __scripter_ui_out=$(date +%s)
  fi
}

# ui::group_begin <title> / ui::group_end — collapsible sections in CI
ui::group_begin() {
  local __scripter_title="$*" __scripter_depth
  __scripter_ui_init
  __scripter_depth=${#__scripter_ui_groups[@]}
  __scripter_ui_groups+=("$__scripter_title")
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo | ci:azure)
      if [ "$__scripter_depth" -gt 0 ]; then
        ui::section "$__scripter_title"
      elif [ "$__scripter_ui_renderer" = ci:azure ]; then
        printf '##[group]%s\n' "$__scripter_title" >&2
      else
        __scripter_ui_escape github "$__scripter_title"
        printf '::group::%s\n' "$__scripter_ui_out" >&2
      fi
      ;;
    ci:gitlab)
      __scripter_ui_group_seq=$((__scripter_ui_group_seq + 1))
      __scripter_ui_group_ids+=("scripter_$$_$__scripter_ui_group_seq")
      __scripter_ui_timestamp
      printf '\e[0Ksection_start:%s:%s[collapsed=true]\r\e[0K%s%s%s\n' "$__scripter_ui_out" \
        "scripter_$$_$__scripter_ui_group_seq" "$__scripter_c_bold" "$__scripter_title" "$__scripter_c_reset" >&2
      ;;
    ci:buildkite)
      printf -- '--- %s\n' "$__scripter_title" >&2
      ;;
    ci:teamcity)
      __scripter_ui_escape teamcity "$__scripter_title"
      printf "##teamcity[blockOpened name='%s']\n" "$__scripter_ui_out" >&2
      ;;
    plain)
      printf '%s==> %s\n' "$__scripter_ui_indent" "$__scripter_title" >&2
      ;;
    *)
      ui::section "$__scripter_title"
      __scripter_ui_indent="$__scripter_ui_indent  "
      ;;
  esac
}

ui::group_end() {
  local __scripter_depth __scripter_title __scripter_id
  __scripter_ui_init
  __scripter_depth=${#__scripter_ui_groups[@]}
  [ "$__scripter_depth" -gt 0 ] || return 0
  __scripter_title=${__scripter_ui_groups[__scripter_depth - 1]}
  unset "__scripter_ui_groups[$((__scripter_depth - 1))]"
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo)
      if [ "$__scripter_depth" -eq 1 ]; then printf '::endgroup::\n' >&2; fi
      ;;
    ci:azure)
      if [ "$__scripter_depth" -eq 1 ]; then printf '##[endgroup]\n' >&2; fi
      ;;
    ci:gitlab)
      __scripter_id=${__scripter_ui_group_ids[${#__scripter_ui_group_ids[@]} - 1]}
      unset "__scripter_ui_group_ids[$((${#__scripter_ui_group_ids[@]} - 1))]"
      __scripter_ui_timestamp
      printf '\e[0Ksection_end:%s:%s\r\e[0K\n' "$__scripter_ui_out" "$__scripter_id" >&2
      ;;
    ci:teamcity)
      __scripter_ui_escape teamcity "$__scripter_title"
      printf "##teamcity[blockClosed name='%s']\n" "$__scripter_ui_out" >&2
      ;;
    plain | ci:*) ;;
    *)
      __scripter_ui_indent=${__scripter_ui_indent%  }
      ;;
  esac
}

# Runs "$@" in a subshell with errexit active; status in __scripter_ui_rc.
__scripter_ui_run() {
  local __scripter_errexit=
  case $- in *e*) __scripter_errexit=1 ;; esac
  set +e
  (
    set -e
    "$@"
  )
  __scripter_ui_rc=$?
  if [ -n "$__scripter_errexit" ]; then set -e; fi
}

__scripter_ui_prefix() {
  local __scripter_line
  while IFS='' read -r __scripter_line || [ -n "$__scripter_line" ]; do
    printf '%s%s\n' "$__scripter_ui_indent" "$__scripter_line"
  done
}

# ui::group <title> -- <cmd>…  (the command runs in a subshell)
ui::group() {
  local __scripter_title=$1
  shift
  if [ "${1:-}" = -- ]; then shift; fi
  ui::group_begin "$__scripter_title"
  if [ "$__scripter_ui_renderer" = fancy ]; then
    __scripter_ui_run __scripter_ui_group_fancy "$@"
  else
    __scripter_ui_run "$@"
  fi
  ui::group_end
  return "$__scripter_ui_rc"
}

__scripter_ui_group_fancy() {
  "$@" 2>&1 | __scripter_ui_prefix >&2
}

# ui::annotate <notice|warning|error> <message> [file] [line]
ui::annotate() {
  local __scripter_level=$1 __scripter_msg=$2 __scripter_file=${3:-} __scripter_line=${4:-} __scripter_props=
  __scripter_ui_init
  case $__scripter_level in
    info | notice) __scripter_level=notice ;;
    warn | warning) __scripter_level=warning ;;
    error) ;;
    *) die "ui::annotate: unknown level '$__scripter_level'" ;;
  esac
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo)
      if [ -n "$__scripter_file" ]; then
        __scripter_ui_escape github-prop "$__scripter_file"
        __scripter_props=" file=$__scripter_ui_out"
        if [ -n "$__scripter_line" ]; then __scripter_props="$__scripter_props,line=$__scripter_line"; fi
      fi
      __scripter_ui_escape github "$__scripter_msg"
      printf '::%s%s::%s\n' "$__scripter_level" "$__scripter_props" "$__scripter_ui_out" >&2
      ;;
    ci:azure)
      if [ "$__scripter_level" = notice ]; then
        ui::info "$__scripter_msg"
        return 0
      fi
      if [ -n "$__scripter_file" ]; then
        __scripter_props=";sourcepath=$__scripter_file"
        if [ -n "$__scripter_line" ]; then __scripter_props="$__scripter_props;linenumber=$__scripter_line"; fi
      fi
      __scripter_ui_escape azure "$__scripter_msg"
      printf '##vso[task.logissue type=%s%s]%s\n' "$__scripter_level" "$__scripter_props" "$__scripter_ui_out" >&2
      ;;
    *)
      if [ -n "$__scripter_file" ]; then
        __scripter_msg="$__scripter_msg ($__scripter_file${__scripter_line:+:$__scripter_line})"
      fi
      case $__scripter_level in
        notice) ui::info "$__scripter_msg" ;;
        warning) ui::warn "$__scripter_msg" ;;
        error) ui::error "$__scripter_msg" ;;
      esac
      ;;
  esac
}

# ui::mask <value>  hide a secret in CI logs
ui::mask() {
  [ -n "${1:-}" ] || return 0
  __scripter_ui_init
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo)
      __scripter_ui_escape github "$1"
      printf '::add-mask::%s\n' "$__scripter_ui_out" >&2
      ;;
    ci:azure)
      __scripter_ui_group_seq=$((__scripter_ui_group_seq + 1))
      printf '##vso[task.setvariable variable=SCRIPTER_MASK_%s;issecret=true]%s\n' "$__scripter_ui_group_seq" "$1" >&2
      ;;
  esac
}

# ui::summary  append markdown from stdin to the CI job summary
ui::summary() {
  local __scripter_file=${SCRIPTER_SUMMARY_FILE:-}
  __scripter_ui_init
  case $__scripter_ui_renderer in
    ci:github | ci:forgejo) __scripter_file=${GITHUB_STEP_SUMMARY:-$__scripter_file} ;;
  esac
  if [ -n "$__scripter_file" ]; then
    cat >>"$__scripter_file"
  else
    cat >/dev/null
  fi
}

# ui::table [--no-header]  render TSV from stdin
ui::table() {
  local __scripter_header=1 __scripter_line __scripter_i __scripter_r __scripter_w __scripter_last
  if [ "${1:-}" = --no-header ]; then __scripter_header=; fi
  __scripter_ui_init
  if [ "$__scripter_ui_renderer" = plain ]; then
    cat >&2
    return 0
  fi
  local -a __scripter_rows=() __scripter_widths=() __scripter_cells=()
  while IFS='' read -r __scripter_line || [ -n "$__scripter_line" ]; do
    __scripter_rows+=("$__scripter_line")
    IFS=$'\t' read -r -a __scripter_cells <<<"$__scripter_line"
    for ((__scripter_i = 0; __scripter_i < ${#__scripter_cells[@]}; __scripter_i++)); do
      __scripter_w=${__scripter_widths[__scripter_i]:-0}
      if [ "${#__scripter_cells[__scripter_i]}" -gt "$__scripter_w" ]; then
        __scripter_widths[__scripter_i]=${#__scripter_cells[__scripter_i]}
      fi
    done
  done
  [ "${#__scripter_rows[@]}" -gt 0 ] || return 0
  for ((__scripter_r = 0; __scripter_r < ${#__scripter_rows[@]}; __scripter_r++)); do
    IFS=$'\t' read -r -a __scripter_cells <<<"${__scripter_rows[__scripter_r]}"
    __scripter_last=$((${#__scripter_cells[@]} - 1))
    __scripter_line=
    for ((__scripter_i = 0; __scripter_i <= __scripter_last; __scripter_i++)); do
      if [ "$__scripter_i" -eq "$__scripter_last" ]; then
        __scripter_line="$__scripter_line${__scripter_cells[__scripter_i]}"
      else
        printf -v __scripter_w '%-*s  ' "${__scripter_widths[__scripter_i]}" "${__scripter_cells[__scripter_i]}"
        __scripter_line="$__scripter_line$__scripter_w"
      fi
    done
    if [ "$__scripter_r" -eq 0 ] && [ -n "$__scripter_header" ]; then
      printf '%s%s%s%s\n' "$__scripter_ui_indent" "$__scripter_c_bold" "$__scripter_line" "$__scripter_c_reset" >&2
      __scripter_w=0
      for ((__scripter_i = 0; __scripter_i < ${#__scripter_widths[@]}; __scripter_i++)); do
        __scripter_w=$((__scripter_w + __scripter_widths[__scripter_i] + 2))
      done
      __scripter_ui_repeat "$__scripter_i_rule" "$((__scripter_w - 2))"
      printf '%s%s%s%s\n' "$__scripter_ui_indent" "$__scripter_c_dim" "$__scripter_ui_out" "$__scripter_c_reset" >&2
    else
      printf '%s%s\n' "$__scripter_ui_indent" "$__scripter_line" >&2
    fi
  done
}

# Milliseconds since an arbitrary point into __scripter_ms (whole seconds before bash 5).
__scripter_now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local __scripter_t=${EPOCHREALTIME//[!0-9]/}
    __scripter_ms=$((10#$__scripter_t / 1000))
  else
    __scripter_ms=$((SECONDS * 1000))
  fi
}

__scripter_fmt_ms() {
  local __scripter_t=$1
  if [ -z "${EPOCHREALTIME:-}" ]; then
    __scripter_ui_out="$((__scripter_t / 1000))s"
  elif [ "$__scripter_t" -lt 1000 ]; then
    __scripter_ui_out="${__scripter_t}ms"
  elif [ "$__scripter_t" -lt 60000 ]; then
    __scripter_ui_out="$((__scripter_t / 1000)).$(((__scripter_t % 1000) / 100))s"
  else
    printf -v __scripter_ui_out '%dm%02ds' "$((__scripter_t / 60000))" "$(((__scripter_t % 60000) / 1000))"
  fi
}

# ui::spin <message> -- <cmd>…  spinner while the command runs (in a subshell);
# its output is shown only if it fails.
ui::spin() {
  local __scripter_msg=$1 __scripter_log __scripter_start __scripter_i=0
  shift
  if [ "${1:-}" = -- ]; then shift; fi
  __scripter_ui_init
  __scripter_now_ms
  __scripter_start=$__scripter_ms

  if [ "$__scripter_ui_renderer" != fancy ]; then
    ui::info "$__scripter_msg ..."
    __scripter_ui_run "$@"
  else
    need_cmd mktemp sleep rm cat
    __scripter_log=$(mktemp)
    (
      set -e
      "$@"
    ) >"$__scripter_log" 2>&1 &
    __scripter_ui_spin_pid=$!
    printf '\e[?25l' >&2
    __scripter_ui_cursor_hidden=1
    while kill -0 "$__scripter_ui_spin_pid" 2>/dev/null; do
      printf '\r\e[K%s%s%s%s %s' "$__scripter_ui_indent" "$__scripter_c_accent" \
        "${__scripter_ui_frames[__scripter_i % ${#__scripter_ui_frames[@]}]}" "$__scripter_c_reset" "$__scripter_msg" >&2
      __scripter_i=$((__scripter_i + 1))
      sleep 0.1
    done
    __scripter_ui_rc=0
    wait "$__scripter_ui_spin_pid" || __scripter_ui_rc=$?
    __scripter_ui_spin_pid=
    printf '\r\e[K\e[?25h' >&2
    __scripter_ui_cursor_hidden=
  fi

  __scripter_now_ms
  __scripter_fmt_ms "$((__scripter_ms - __scripter_start))"
  if [ "$__scripter_ui_rc" -eq 0 ]; then
    ui::success "$__scripter_msg $__scripter_c_dim($__scripter_ui_out)$__scripter_c_reset"
  else
    ui::error "$__scripter_msg failed with exit code $__scripter_ui_rc $__scripter_c_dim($__scripter_ui_out)$__scripter_c_reset"
    if [ -n "${__scripter_log:-}" ]; then
      __scripter_ui_prefix <"$__scripter_log" >&2
    fi
  fi
  if [ -n "${__scripter_log:-}" ]; then rm -f "$__scripter_log"; fi
  return "$__scripter_ui_rc"
}

# ui::progress <current> <total> [message]
ui::progress() {
  local __scripter_cur=$1 __scripter_total=$2 __scripter_msg=${3:-} __scripter_pct __scripter_fill
  __scripter_ui_init
  __scripter_ui_visible info || return 0
  if [ "$__scripter_total" -le 0 ]; then __scripter_total=1; fi
  __scripter_pct=$((__scripter_cur * 100 / __scripter_total))
  if [ "$__scripter_pct" -gt 100 ]; then __scripter_pct=100; fi
  if [ "$__scripter_pct" -lt 0 ]; then __scripter_pct=0; fi

  if [ "$__scripter_ui_renderer" = fancy ]; then
    __scripter_fill=$((__scripter_pct * 30 / 100))
    __scripter_ui_repeat "$__scripter_i_bar_full" "$__scripter_fill"
    local __scripter_bar=$__scripter_ui_out
    __scripter_ui_repeat "$__scripter_i_bar_empty" "$((30 - __scripter_fill))"
    printf '\r\e[K%s%s%s%s%s %3d%% %s' "$__scripter_ui_indent" "$__scripter_c_accent" "$__scripter_bar" \
      "$__scripter_c_dim$__scripter_ui_out" "$__scripter_c_reset" "$__scripter_pct" "$__scripter_msg" >&2
    if [ "$__scripter_cur" -ge "$__scripter_total" ]; then printf '\n' >&2; fi
    return 0
  fi

  # elsewhere: one line per 10% step
  if [ "$((__scripter_pct / 10))" != "${__scripter_ui_progress_last:-}" ]; then
    __scripter_ui_progress_last=$((__scripter_pct / 10))
    ui::info "${__scripter_msg:+$__scripter_msg: }$__scripter_pct%"
  fi
  if [ "$__scripter_cur" -ge "$__scripter_total" ]; then __scripter_ui_progress_last=; fi
}
