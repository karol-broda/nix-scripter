{ lib }:
let
  inherit (lib) mkOption types;
  level = import ./level.nix { inherit lib; };

  boolOption =
    default: description:
    mkOption {
      type = types.bool;
      inherit default description;
    };

  globals = {
    help = boolOption true "`-h/--help`.";
    version = boolOption true "`--version`.";
    verbose = boolOption false "`-v/--verbose`, repeatable; sets SCRIPTER_LOG_LEVEL=debug.";
    quiet = boolOption false "`-q/--quiet`; sets SCRIPTER_LOG_LEVEL=warn.";
    color = boolOption false "`--color=auto|always|never`; sets SCRIPTER_COLOR.";
    yes = boolOption false "`-y/--yes`; sets SCRIPTER_YES=1.";
    dryRun = boolOption false "`--dry-run`; sets SCRIPTER_DRY_RUN=1.";
  };

  vars = {
    style = mkOption {
      type = types.nullOr (
        types.enum [
          "assoc"
          "globals"
        ]
      );
      default = null;
      description = "`assoc` (`args[key]`) or `globals` (`ARG_KEY`); defaults to the best the target supports.";
    };
    name = mkOption {
      type = types.str;
      default = "args";
    };
    prefix = mkOption {
      type = types.str;
      default = "ARG_";
    };
    listPrefix = mkOption {
      type = types.str;
      default = "args_";
    };
    case = mkOption {
      type = types.enum [
        "upper"
        "lower"
        "keep"
      ];
      default = "upper";
    };
    command = mkOption {
      type = types.str;
      default = "_command";
      description = "Key holding the selected subcommand path.";
    };
  };

  testCase = {
    options = {
      argv = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      expect = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Subset of the parsed values; `_command` is the subcommand path.";
      };
      exitCode = mkOption {
        type = types.int;
        default = 0;
      };
      stdoutContains = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      stderrContains = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  declaresArguments =
    config:
    config.flags != { } || config.options != { } || config.positional != [ ] || config.commands != { };
in
{ config, ... }:
{
  imports = [ level ];
  options = {
    enable = mkOption {
      type = types.bool;
      default = declaresArguments config;
      defaultText = lib.literalMD "whether any flag, option, positional or command is declared";
      description = "Generate a parser; without it the script receives `$@` untouched.";
    };
    inherit globals vars;
    defaults.negatable = boolOption false "Default `negatable` for every flag and bool option.";
    tests = mkOption {
      type = types.listOf (types.submodule testCase);
      default = [ ];
    };
  };
}
