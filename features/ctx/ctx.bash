# --- nix-scripter: ctx -------------------------------------------------------

# Value-returning functions accept `-v <var>` to assign instead of printing.
__scripter_ret() {
  if [ -n "$1" ]; then
    printf -v "$1" '%s' "$2"
  else
    printf '%s\n' "$2"
  fi
}

__scripter_detect_ci() {
  __scripter_ci=
  case ${SCRIPTER_CI:-} in
    none | 0 | false) return 0 ;;
    ?*)
      __scripter_ci=$SCRIPTER_CI
      return 0
      ;;
  esac
  if [ -n "${FORGEJO_ACTIONS:-}" ] || [ -n "${GITEA_ACTIONS:-}" ]; then
    __scripter_ci=forgejo
  elif [ "${GITHUB_ACTIONS:-}" = true ]; then
    __scripter_ci=github
  elif [ -n "${GITLAB_CI:-}" ]; then
    __scripter_ci=gitlab
  elif [ "${BUILDKITE:-}" = true ]; then
    __scripter_ci=buildkite
  elif [ -n "${TF_BUILD:-}" ]; then
    __scripter_ci=azure
  elif [ -n "${TEAMCITY_VERSION:-}" ]; then
    __scripter_ci=teamcity
  elif [ -n "${JENKINS_URL:-}" ]; then
    __scripter_ci=jenkins
  elif [ -n "${CIRCLECI:-}" ]; then
    __scripter_ci=circleci
  elif [ "${CI:-}" = woodpecker ]; then
    __scripter_ci=woodpecker
  elif [ -n "${DRONE:-}" ]; then
    __scripter_ci=drone
  else
    case ${CI:-} in
      '' | 0 | false | False | FALSE) ;;
      *) __scripter_ci=generic ;;
    esac
  fi
}

# ctx::ci_provider [-v var]  github, gitlab, …, generic, or empty
ctx::ci_provider() {
  local __scripter_var=
  if [ "${1:-}" = -v ]; then __scripter_var=$2; fi
  if [ -z "${__scripter_ci+x}" ]; then __scripter_detect_ci; fi
  __scripter_ret "$__scripter_var" "$__scripter_ci"
}

ctx::is_ci() {
  if [ -z "${__scripter_ci+x}" ]; then __scripter_detect_ci; fi
  [ -n "$__scripter_ci" ]
}

# stderr is a terminal (all UI output goes to stderr)
ctx::is_tty() {
  [ -t 2 ]
}

ctx::is_interactive() {
  [ -t 0 ] && [ -t 2 ] && ! ctx::is_ci
}

# ctx::color  status 0 when colors should be used on stderr
ctx::color() {
  if [ -z "${__scripter_color+x}" ]; then
    __scripter_color=
    case ${SCRIPTER_COLOR:-auto} in
      always | yes | 1) __scripter_color=1 ;;
      never | no | 0) ;;
      *)
        if [ -n "${NO_COLOR:-}" ]; then
          :
        elif [ -n "${FORCE_COLOR:-}" ] && [ "${FORCE_COLOR}" != 0 ]; then
          __scripter_color=1
        elif [ -n "${CLICOLOR_FORCE:-}" ] && [ "${CLICOLOR_FORCE}" != 0 ]; then
          __scripter_color=1
        elif [ "${TERM:-}" = dumb ]; then
          :
        elif ctx::is_ci; then
          case $__scripter_ci in
            github | forgejo | gitlab | buildkite | azure | teamcity | woodpecker | drone | circleci) __scripter_color=1 ;;
          esac
        elif ctx::is_tty; then
          __scripter_color=1
        fi
        ;;
    esac
  fi
  [ -n "$__scripter_color" ]
}

ctx::os() {
  local __scripter_var='' __scripter_os
  if [ "${1:-}" = -v ]; then __scripter_var=$2; fi
  case ${OSTYPE:-} in
    linux*) __scripter_os=linux ;;
    darwin*) __scripter_os=darwin ;;
    freebsd*) __scripter_os=freebsd ;;
    openbsd*) __scripter_os=openbsd ;;
    netbsd*) __scripter_os=netbsd ;;
    msys* | cygwin* | win*) __scripter_os=windows ;;
    *) __scripter_os=$(uname -s | tr '[:upper:]' '[:lower:]') ;;
  esac
  __scripter_ret "$__scripter_var" "$__scripter_os"
}

ctx::arch() {
  local __scripter_var='' __scripter_arch
  if [ "${1:-}" = -v ]; then __scripter_var=$2; fi
  __scripter_arch=${HOSTTYPE:-}
  if [ -z "$__scripter_arch" ]; then __scripter_arch=$(uname -m); fi
  case $__scripter_arch in
    arm64 | aarch64) __scripter_arch=aarch64 ;;
    amd64 | x86_64) __scripter_arch=x86_64 ;;
    i?86) __scripter_arch=i686 ;;
  esac
  __scripter_ret "$__scripter_var" "$__scripter_arch"
}

ctx::is_nixos() {
  [ -e /etc/NIXOS ]
}

ctx::is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]
}

ctx::is_container() {
  [ -e /.dockerenv ] || [ -e /run/.containerenv ] || [ -n "${container:-}" ] ||
    [ -n "${KUBERNETES_SERVICE_HOST:-}" ]
}

ctx::in_nix_shell() {
  [ -n "${IN_NIX_SHELL:-}" ]
}

# ctx::renderer [-v var]  fancy, plain or ci:<provider>
ctx::renderer() {
  local __scripter_var='' __scripter_r
  if [ "${1:-}" = -v ]; then __scripter_var=$2; fi
  if [ -z "${__scripter_ci+x}" ]; then __scripter_detect_ci; fi
  case ${SCRIPTER_UI:-auto} in
    fancy | plain) __scripter_r=$SCRIPTER_UI ;;
    ci) __scripter_r="ci:${__scripter_ci:-generic}" ;;
    *)
      if [ -n "$__scripter_ci" ]; then
        __scripter_r="ci:$__scripter_ci"
      elif ctx::is_tty; then
        __scripter_r=fancy
      else
        __scripter_r=plain
      fi
      ;;
  esac
  __scripter_ret "$__scripter_var" "$__scripter_r"
}

__scripter_flag() {
  if "$@"; then printf 1; fi
}

# ctx::info -v <assoc array>  everything above in one associative array
ctx::info() {
  if [ "${1:-}" != -v ] || [ -z "${2:-}" ]; then
    die "usage: ctx::info -v <associative array>"
  fi
  local -n __scripter_info=$2
  local __scripter_v
  ctx::ci_provider -v __scripter_v
  __scripter_info["ci"]=$__scripter_v
  ctx::os -v __scripter_v
  __scripter_info["os"]=$__scripter_v
  ctx::arch -v __scripter_v
  __scripter_info["arch"]=$__scripter_v
  ctx::renderer -v __scripter_v
  __scripter_info["renderer"]=$__scripter_v
  __scripter_info["tty"]=$(__scripter_flag ctx::is_tty)
  __scripter_info["interactive"]=$(__scripter_flag ctx::is_interactive)
  __scripter_info["color"]=$(__scripter_flag ctx::color)
  __scripter_info["nixos"]=$(__scripter_flag ctx::is_nixos)
  __scripter_info["wsl"]=$(__scripter_flag ctx::is_wsl)
  __scripter_info["container"]=$(__scripter_flag ctx::is_container)
  __scripter_info["nix_shell"]=$(__scripter_flag ctx::in_nix_shell)
}
