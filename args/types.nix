# Module-system types of the argument spec. A spec is a tree of levels: the
# root level plus nested `commands`.
{ lib }:
let
  inherit (lib) mkOption types;

  shortType = types.nullOr (types.strMatching "[A-Za-z0-9]");
  nameType = types.strMatching "[A-Za-z][A-Za-z0-9_-]*";

  valueTypes = [
    "str"
    "int"
    "float"
    "bool"
    "path"
    "file"
    "dir"
    "enum"
  ];

  common = {
    description = mkOption {
      type = types.str;
      default = "";
      description = "Shown in `--help` and completions.";
    };
    env = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Environment variable used when the argument is not given.";
    };
    var = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Override of the generated variable name / key.";
    };
    hidden = mkOption {
      type = types.bool;
      default = false;
      description = "Hide from help and completions.";
    };
  };

  valued =
    config:
    {
      type = mkOption {
        type = types.enum valueTypes;
        default = if config.values != null then "enum" else "str";
        description = "Value type; validated by the generated parser.";
      };
      values = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Allowed values (implies `type = \"enum\"`).";
      };
      pattern = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Extended regular expression the value must match.";
      };
      default = mkOption {
        type = types.nullOr (
          types.oneOf [
            types.str
            types.int
            types.float
            types.bool
            (types.listOf types.str)
          ]
        );
        default = null;
        description = "Value used when neither the argument nor `env` is given.";
      };
      complete = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Opt-in dynamic completion: a shell command whose output lines are
          offered as candidates. Runs every time completion is requested.
        '';
      };
    }
    // common;

  flag =
    { name, ... }:
    {
      options = {
        short = mkOption {
          type = shortType;
          default = null;
        };
        long = mkOption {
          type = nameType;
          default = name;
        };
        negatable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Also accept `--no-<long>` (default: `args.defaults.negatable`).";
        };
        count = mkOption {
          type = types.bool;
          default = false;
          description = "Count occurrences (`-vvv` → 3) instead of a boolean.";
        };
      }
      // common;
    };

  option =
    { name, config, ... }:
    {
      options = {
        short = mkOption {
          type = shortType;
          default = null;
        };
        long = mkOption {
          type = nameType;
          default = name;
        };
        metavar = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        required = mkOption {
          type = types.bool;
          default = false;
        };
        repeated = mkOption {
          type = types.bool;
          default = false;
          description = "Accept the option multiple times; the value is a list.";
        };
        negatable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "For `type = \"bool\"`: also accept `--no-<long>`.";
        };
      }
      // valued config;
    };

  positional =
    { config, ... }:
    {
      options = {
        name = mkOption {
          type = nameType;
          description = "Name shown in usage and used as key.";
        };
        optional = mkOption {
          type = types.bool;
          default = false;
        };
        variadic = mkOption {
          type = types.bool;
          default = false;
          description = "Collect all remaining arguments (must be last).";
        };
      }
      // valued config;
    };

  constraint = {
    options = {
      exclusive = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "At most one of these may be given.";
      };
      requires = mkOption {
        type = types.nullOr (types.attrsOf (types.listOf types.str));
        default = null;
        description = "`{ a = [ \"b\" ]; }`: giving `a` requires giving `b`.";
      };
      oneOf = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Exactly one of these must be given.";
      };
    };
  };

  example = {
    options = {
      cmd = mkOption { type = types.str; };
      description = mkOption {
        type = types.str;
        default = "";
      };
    };
  };

  level =
    { ... }:
    {
      options = {
        description = mkOption {
          type = types.str;
          default = "";
        };
        aliases = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        hidden = mkOption {
          type = types.bool;
          default = false;
        };
        flags = mkOption {
          type = types.attrsOf (types.submodule flag);
          default = { };
        };
        options = mkOption {
          type = types.attrsOf (types.submodule option);
          default = { };
        };
        positional = mkOption {
          type = types.listOf (types.submodule positional);
          default = [ ];
          description = "Positional arguments, in order.";
        };
        constraints = mkOption {
          type = types.listOf (types.submodule constraint);
          default = [ ];
        };
        groups = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = "Help sections: group title → argument names.";
        };
        examples = mkOption {
          type = types.listOf (types.submodule example);
          default = [ ];
        };
        commands = mkOption {
          type = types.attrsOf (types.submodule level);
          default = { };
          description = "Subcommands, each a level of its own.";
        };
        inheritGlobals = mkOption {
          type = types.bool;
          default = true;
          description = "Accept the parent level's flags and options after this subcommand.";
        };
        text = mkOption {
          type = types.nullOr types.lines;
          default = null;
          description = ''
            Body of this subcommand. Without `text`/`src`, the dispatcher calls
            the function `cmd::<path>` defined by the script.
          '';
        };
        src = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
      };
    };

  globalsOptions =
    lib.mapAttrs
      (
        _: description:
        mkOption {
          type = types.bool;
          default = false;
          inherit description;
        }
      )
      {
        verbose = "`-v/--verbose`, repeatable; sets SCRIPTER_LOG_LEVEL=debug.";
        quiet = "`-q/--quiet`; sets SCRIPTER_LOG_LEVEL=warn.";
        color = "`--color=auto|always|never`; sets SCRIPTER_COLOR.";
        yes = "`-y/--yes`; sets SCRIPTER_YES=1 (auto-confirm prompts).";
        dryRun = "`--dry-run`; sets SCRIPTER_DRY_RUN=1.";
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
        description = "Parsed values to compare (subset). `_command` is the subcommand path.";
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

  root =
    { config, ... }:
    {
      imports = [ level ];
      options = {
        enable = mkOption {
          type = types.bool;
          default =
            config.flags != { } || config.options != { } || config.positional != [ ] || config.commands != { };
          defaultText = lib.literalMD "`true` when any flag, option, positional or command is declared";
          description = "Generate a parser. Without it the script gets `$@` untouched.";
        };
        globals = {
          help = mkOption {
            type = types.bool;
            default = true;
            description = "`-h/--help`.";
          };
          version = mkOption {
            type = types.bool;
            default = true;
            description = "`--version`.";
          };
        }
        // globalsOptions;
        defaults.negatable = mkOption {
          type = types.bool;
          default = false;
          description = "Default of `negatable` for every flag and bool option.";
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
            description = "`assoc` (`args[key]`) or `globals` (`ARG_KEY`). Default: best the target supports.";
          };
          name = mkOption {
            type = types.str;
            default = "args";
            description = "Name of the associative array / record.";
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
        tests = mkOption {
          type = types.listOf (types.submodule testCase);
          default = [ ];
          description = "Parser test cases, run as a check.";
        };
      };
    };
in
{
  inherit root level valueTypes;
}
