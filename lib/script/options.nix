{ lib, config, ... }:
let
  inherit (lib) mkOption types;

  dependency = types.either types.package (
    types.submodule {
      options = {
        pkg = mkOption { type = types.package; };
        commands = mkOption {
          type = types.listOf types.str;
          description = "Commands the package provides, checked at startup in standalone mode.";
        };
      };
    }
  );

  enum =
    values: default:
    mkOption {
      type = types.enum values;
      inherit default;
    };
in
{
  options = {
    name = mkOption { type = types.strMatching "[A-Za-z0-9][A-Za-z0-9._+-]*"; };

    text = mkOption {
      type = types.nullOr types.lines;
      default = null;
    };

    src = mkOption {
      type = types.nullOr types.path;
      default = null;
    };

    description = mkOption {
      type = types.str;
      default = "";
    };

    version = mkOption {
      type = types.str;
      default = "0.0.0";
    };

    mode =
      enum [
        "linked"
        "standalone"
      ] "linked"
      // {
        description = ''
          `linked`: dependencies come from the Nix store. `standalone`: the
          output has no store references and runs on any host with the
          interpreter.
        '';
      };

    deps = mkOption {
      type = types.listOf dependency;
      default = [ ];
      description = "Linked: put on PATH. Standalone: their commands are checked at startup.";
    };

    requires = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Commands expected on the host, checked at startup in both modes.";
    };

    path =
      enum [
        "prefix"
        "suffix"
        "replace"
      ] "prefix"
      // {
        description = "How linked dependencies join PATH; `replace` is hermetic.";
      };

    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
    };

    meta = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };

    passthru = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };

    assertions = mkOption {
      type = types.listOf types.unspecified;
      internal = true;
      default = [ ];
    };
  };

  config.assertions = [
    {
      assertion = (config.text == null) != (config.src == null);
      message = "exactly one of `text` or `src` must be set";
    }
    {
      assertion = !(config.path == "replace" && config.requires != [ ]);
      message = "`path = \"replace\"` is hermetic and cannot be combined with `requires`";
    }
  ];
}
