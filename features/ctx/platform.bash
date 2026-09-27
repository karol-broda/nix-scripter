ctx::os() {
  local __scripter_os
  __scripter_ret_var "$@"
  case ${OSTYPE:-} in
    linux*) __scripter_os=linux ;;
    darwin*) __scripter_os=darwin ;;
    freebsd*) __scripter_os=freebsd ;;
    openbsd*) __scripter_os=openbsd ;;
    netbsd*) __scripter_os=netbsd ;;
    msys* | cygwin* | win*) __scripter_os=windows ;;
    *) __scripter_os=$(uname -s | tr '[:upper:]' '[:lower:]') ;;
  esac
  __scripter_ret "$__scripter_ret_to" "$__scripter_os"
}

ctx::arch() {
  local __scripter_arch=${HOSTTYPE:-}
  __scripter_ret_var "$@"
  if [ -z "$__scripter_arch" ]; then __scripter_arch=$(uname -m); fi
  case $__scripter_arch in
    arm64 | aarch64) __scripter_arch=aarch64 ;;
    amd64 | x86_64) __scripter_arch=x86_64 ;;
    i?86) __scripter_arch=i686 ;;
  esac
  __scripter_ret "$__scripter_ret_to" "$__scripter_arch"
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
