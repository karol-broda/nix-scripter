# Pure, pkgs-independent entry point. Everything that needs `pkgs` goes
# through `mkScripter`.
{ lib }:
let
  registry = import ./registry.nix { inherit lib; };

  scripterLib = {
    mkScripter =
      {
        pkgs,
        modules ? [ ],
        extensions ? [ ],
      }:
      import ./instance.nix {
        inherit lib pkgs scripterLib;
        registry = lib.foldl' (r: ext: r.extend ext) registry extensions;
        defaultModules = modules;
      };

    inherit registry;
    inherit (registry) presets;

    discover = import ./discover.nix { inherit lib registry; };

    args = import ../args { inherit lib; };
  };
in
scripterLib
