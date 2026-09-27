{
  lib,
  pkgs,
  registry,
  defaultModules,
  scripterLib,
}:
let
  mkInstance =
    { registry, defaultModules }:
    let
      evalScript =
        module:
        lib.evalModules {
          class = "scripter";
          modules = [ (import ./script { inherit registry; }) ] ++ defaultModules ++ [ module ];
          specialArgs = {
            inherit pkgs;
            scripter = self;
          };
        };

      mkScript =
        module:
        let
          evaluated = evalScript module;
        in
        import ./pipeline {
          inherit lib pkgs registry;
          inherit (evaluated) config;
          extend =
            extra:
            mkScript {
              imports = [
                module
                extra
              ];
            };
        };

      shorthands = lib.mapAttrs (
        lang: _: module:
        mkScript {
          imports = [ module ];
          inherit lang;
        }
      ) registry.backends;

      self = shorthands // {
        inherit
          mkScript
          evalScript
          registry
          pkgs
          ;
        inherit (registry) presets;
        lib = scripterLib;

        withDefaults =
          module:
          mkInstance {
            inherit registry;
            defaultModules = defaultModules ++ [ module ];
          };

        extend =
          ext:
          mkInstance {
            registry = registry.extend ext;
            inherit defaultModules;
          };

        discover = args: import ./discover.nix { inherit lib registry; } args;

        args = import ../args/instance.nix {
          inherit lib pkgs registry;
        };
      };
    in
    self;
in
mkInstance { inherit registry defaultModules; }
