{ lib }:
{
  description = "Environment detection: CI provider, TTY, colors, OS, privileges of the session.";
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

  impl.bash = _: builtins.readFile ./ctx.bash;
}
