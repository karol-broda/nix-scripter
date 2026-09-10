# Option schema of a single script. Feature, checker and backend options are
# generated from the registry, so extensions get first-class options too.
{ registry }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  argsTypes = import ../args/types.nix { inherit lib; };

  dependentsOf =
    name: lib.attrNames (lib.filterAttrs (_: f: lib.elem name (f.requires or [ ])) registry.features);

  featureOption =
    name: feature:
    mkOption {
      description = feature.description or "The ${name} feature.";
      default = { };
      type = types.coercedTo types.bool (enable: { inherit enable; }) (
        types.submoduleWith {
          specialArgs = { inherit pkgs; };
          modules = [
            {
              options.enable = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable the ${name} feature.";
              };
            }
          ]
          ++ lib.optional (feature ? options) feature.options;
        }
      );
    };

  checkerOption =
    name: checker:
    mkOption {
      description = checker.description or "The ${name} checker.";
      default = { };
      type = types.submoduleWith {
        specialArgs = { inherit pkgs; };
        modules = [
          {
            options.enable = mkOption {
              type = types.bool;
              default = checker.defaultEnable or false;
              description = "Whether to run ${name}.";
            };
            options.stage = mkOption {
              type = types.enum [
                "build"
                "flake-check"
              ];
              default = checker.defaultStage or "flake-check";
              description = ''
                `build` fails the script's derivation; `flake-check` creates a
                separate derivation in `passthru.checks`.
              '';
            };
          }
        ]
        ++ lib.optional (checker ? options) checker.options;
      };
    };

  backendOption =
    name: backend:
    mkOption {
      description = "Options of the ${name} backend.";
      default = { };
      type = types.submoduleWith {
        specialArgs = {
          inherit pkgs;
          script = config;
        };
        modules = lib.optional (backend ? options) backend.options;
      };
    };

  depType = types.either types.package (
    types.submodule {
      options = {
        pkg = mkOption {
          type = types.package;
          description = "The package to put on PATH (linked mode).";
        };
        commands = mkOption {
          type = types.listOf types.str;
          description = "Commands it provides (checked at startup in standalone mode).";
        };
      };
    }
  );
in
{
  options = {
    name = mkOption {
      type = types.strMatching "[A-Za-z0-9][A-Za-z0-9._+-]*";
      description = "Name of the script and its binary.";
    };

    lang = mkOption {
      type = types.enum (lib.attrNames registry.backends);
      description = "Backend (language) the script is written in.";
    };

    text = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = "Script source. Mutually exclusive with `src`.";
    };

    src = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Script source file. Mutually exclusive with `text`.";
    };

    description = mkOption {
      type = types.str;
      default = "";
      description = "Short description, used for `--help` and `meta.description`.";
    };

    version = mkOption {
      type = types.str;
      default = "0.0.0";
      description = "Version printed by `--version`.";
    };

    mode = mkOption {
      type = types.enum [
        "linked"
        "standalone"
      ];
      default = "linked";
      description = ''
        `linked`: dependencies come from the Nix store. `standalone`: the
        output has no store references and runs on any host with the
        interpreter.
      '';
    };

    deps = mkOption {
      type = types.listOf depType;
      default = [ ];
      description = ''
        Runtime dependencies. Linked: put on PATH. Standalone: their commands
        are checked at startup.
      '';
    };

    requires = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Commands expected on the host, checked at startup in both modes.";
    };

    path = mkOption {
      type = types.enum [
        "prefix"
        "suffix"
        "replace"
      ];
      default = "prefix";
      description = "How linked dependencies join PATH. `replace` is hermetic.";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Static environment variables exported at startup.";
    };

    features = mkOption {
      description = "Runtime library features. All are off by default.";
      default = { };
      type = types.submodule {
        options = lib.mapAttrs featureOption registry.features;
      };
    };

    args = mkOption {
      description = "Command line interface; generates parser, help and completions.";
      default = { };
      type = types.submodule argsTypes.root;
    };

    check = mkOption {
      description = "Static checks of the generated source.";
      default = { };
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Master switch for all checkers.";
          };
        }
        // lib.mapAttrs checkerOption registry.checkers;
      };
    };

    meta = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Merged into the derivation's `meta`.";
    };

    passthru = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extra attributes merged into the derivation's `passthru`.";
    };

    assertions = mkOption {
      type = types.listOf types.unspecified;
      internal = true;
      default = [ ];
    };
  }
  // lib.mapAttrs backendOption registry.backends;

  config = {
    # Enabling a feature enables what it requires (overridable, then asserted).
    features = lib.mapAttrs (name: _: {
      enable = lib.mkIf (lib.any (d: config.features.${d}.enable) (dependentsOf name)) (
        lib.mkDefault true
      );
    }) registry.features;

    assertions = [
      {
        assertion = (config.text == null) != (config.src == null);
        message = "exactly one of `text` or `src` must be set";
      }
      {
        assertion = !(config.path == "replace" && config.requires != [ ]);
        message = "`path = \"replace\"` is hermetic and cannot be combined with `requires`";
      }
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: feature:
        map (dep: {
          assertion = !config.features.${name}.enable || config.features.${dep}.enable;
          message = "features.${name} requires features.${dep}, which is disabled";
        }) (feature.requires or [ ])
      ) registry.features
    );
  };
}
