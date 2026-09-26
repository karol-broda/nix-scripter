{ lib }:
let
  inherit (lib) mkOption types;

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

  shortName = types.nullOr (types.strMatching "[A-Za-z0-9]");
  longName = types.strMatching "[A-Za-z][A-Za-z0-9_-]*";

  commonOptions = {
    description = mkOption {
      type = types.str;
      default = "";
    };
    env = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Environment variable used when the argument is not given.";
    };
    var = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Overrides the generated variable name / key.";
    };
    hidden = mkOption {
      type = types.bool;
      default = false;
    };
  };

  namedOptions = name: {
    short = mkOption {
      type = shortName;
      default = null;
    };
    long = mkOption {
      type = longName;
      default = name;
    };
    negatable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Also accept `--no-<long>`; defaults to `args.defaults.negatable`.";
    };
  };

  valueOptions = config: {
    type = mkOption {
      type = types.enum valueTypes;
      default = if config.values != null then "enum" else "str";
    };
    values = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
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
    };
    complete = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Opt-in dynamic completion: a shell command whose output lines are
        offered as candidates. It runs every time completion is requested.
      '';
    };
  };

  flag =
    { name, ... }:
    {
      options =
        commonOptions
        // namedOptions name
        // {
          count = mkOption {
            type = types.bool;
            default = false;
            description = "Count occurrences (`-vvv` is 3) instead of a boolean.";
          };
        };
    };

  option =
    { name, config, ... }:
    {
      options =
        commonOptions
        // namedOptions name
        // valueOptions config
        // {
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
        };
    };

  positional =
    { config, ... }:
    {
      options =
        commonOptions
        // valueOptions config
        // {
          name = mkOption { type = longName; };
          optional = mkOption {
            type = types.bool;
            default = false;
          };
          variadic = mkOption {
            type = types.bool;
            default = false;
            description = "Collect all remaining arguments; must be the last positional.";
          };
        };
    };
in
{
  inherit
    valueTypes
    flag
    option
    positional
    ;
}
