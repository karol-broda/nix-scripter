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
