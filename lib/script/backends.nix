{ registry }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  backendOption =
    name: backend:
    lib.mkOption {
      description = "Options of the ${name} backend.";
      default = { };
      type = lib.types.submoduleWith {
        specialArgs = {
          inherit pkgs;
          script = config;
        };
        modules = lib.optional (backend ? options) backend.options;
      };
    };
in
{
  options = lib.mapAttrs backendOption registry.backends // {
    lang = lib.mkOption {
      type = lib.types.enum (lib.attrNames registry.backends);
      description = "Backend the script is written for.";
    };
  };
}
