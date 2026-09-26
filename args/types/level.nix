{ lib }:
let
  inherit (lib) mkOption types;
  arguments = import ./arguments.nix { inherit lib; };

  nullableList = mkOption {
    type = types.nullOr (types.listOf types.str);
    default = null;
  };

  constraint = {
    options = {
      exclusive = nullableList // {
        description = "At most one of these may be given.";
      };
      oneOf = nullableList // {
        description = "Exactly one of these must be given.";
      };
      requires = mkOption {
        type = types.nullOr (types.attrsOf (types.listOf types.str));
        default = null;
        description = "`{ a = [ \"b\" ]; }`: giving `a` requires giving `b`.";
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

  level = _: {
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
        type = types.attrsOf (types.submodule arguments.flag);
        default = { };
      };
      options = mkOption {
        type = types.attrsOf (types.submodule arguments.option);
        default = { };
      };
      positional = mkOption {
        type = types.listOf (types.submodule arguments.positional);
        default = [ ];
      };
      constraints = mkOption {
        type = types.listOf (types.submodule constraint);
        default = [ ];
      };
      groups = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "Help sections, from section title to argument names.";
      };
      examples = mkOption {
        type = types.listOf (types.submodule example);
        default = [ ];
      };
      commands = mkOption {
        type = types.attrsOf (types.submodule level);
        default = { };
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
          Body of this subcommand. Without `text` or `src`, the dispatcher
          calls the function `cmd::<path>` that the script defines.
        '';
      };
      src = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
    };
  };
in
level
