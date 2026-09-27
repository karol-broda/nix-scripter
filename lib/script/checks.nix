{ registry }:
{ lib, pkgs, ... }:
let
  inherit (lib) mkOption types;

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
in
{
  options.check = mkOption {
    description = "Static checks of the generated source.";
    default = { };
    type = types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
      }
      // lib.mapAttrs checkerOption registry.checkers;
    };
  };
}
