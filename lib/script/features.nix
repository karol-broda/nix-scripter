{ registry }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  requiresOf = name: registry.features.${name}.requires or [ ];
  dependentsOf =
    name: lib.attrNames (lib.filterAttrs (n: _: lib.elem name (requiresOf n)) registry.features);
  anyEnabled = lib.any (n: config.features.${n}.enable);

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
              };
            }
          ]
          ++ lib.optional (feature ? options) feature.options;
        }
      );
    };

  enabledByDependents = name: {
    enable = lib.mkIf (anyEnabled (dependentsOf name)) (lib.mkDefault true);
  };

  requirementAssertions =
    name:
    map (dep: {
      assertion = !config.features.${name}.enable || config.features.${dep}.enable;
      message = "features.${name} requires features.${dep}, which is disabled";
    }) (requiresOf name);
in
{
  options.features = mkOption {
    description = "Runtime library features; all are off by default.";
    default = { };
    type = types.submodule { options = lib.mapAttrs featureOption registry.features; };
  };

  config = {
    features = lib.mapAttrs (name: _: enabledByDependents name) registry.features;
    assertions = lib.concatMap requirementAssertions (lib.attrNames registry.features);
  };
}
