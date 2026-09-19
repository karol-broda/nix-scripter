{ lib }:
{
  description = "Errors, exit handlers, temporary directories and dry-run aware command execution.";
  namespace = "core";
  requires = [ ];
  deps = pkgs: [ pkgs.coreutils ];

  options =
    { lib, ... }:
    {
      options.stacktrace = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          On an unhandled error, print the failing command, its location in
          the user's source and the call stack.
        '';
      };
    };

  functions = {
    die.bare = true;
    on_exit.bare = true;
    need_cmd.bare = true;
    mktemp_dir = {
      bare = true;
      commands = [
        "mktemp"
        "rm"
      ];
    };
    is_true.bare = true;
    run.bare = true;
    stacktrace = {
      tier = "E";
      needs = [ "err-trap" ];
    };
  };

  impl.bash =
    { cfg, ... }:
    ''
      __scripter_core_stacktrace=${if cfg.stacktrace then "1" else "''"}
    ''
    + builtins.readFile ./core.bash;
}
