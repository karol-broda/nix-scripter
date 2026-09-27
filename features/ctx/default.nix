{ lib }:
let
  inherit (import ../../lib/util.nix { inherit lib; }) readFiles;
in
{
  description = "Environment detection: CI provider, terminal, colors and platform.";
  namespace = "ctx";
  requires = [ "core" ];

  functions = {
    is_ci = { };
    ci_provider = { };
    is_tty = { };
    is_interactive = { };
    color = { };
    os = { };
    arch = { };
    is_nixos = { };
    is_wsl = { };
    is_container = { };
    in_nix_shell = { };
    renderer = { };
    info = {
      tier = "E";
      needs = [
        "assoc-arrays"
        "namerefs"
      ];
    };
  };

  impl.bash =
    _:
    readFiles [
      ./return.bash
      ./ci.bash
      ./terminal.bash
      ./platform.bash
      ./info.bash
    ];
}
