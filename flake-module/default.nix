{ scripterLib }:
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
  top = config.scripter;
in
{
  _file = ./default.nix;

  options.scripter = {
    extensions = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "Registry extensions (`final: prev: { features.x = …; }`) for every system.";
    };
    defaults = mkOption {
      type = types.deferredModule;
      default = { };
      description = "Module applied to every script on every system.";
    };
    scripts = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      description = "System-agnostic script modules, built for every system.";
    };
  };

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    import ./per-system.nix { inherit scripterLib top; }
  );
}
