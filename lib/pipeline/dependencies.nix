{
  lib,
  pkgs,
  registry,
  config,
  context,
  usage,
}:
let
  inherit (lib) concatMap optionals;

  packageOf = d: if lib.isDerivation d then d else d.pkg;
  commandsOf =
    d: if lib.isDerivation d then [ (d.meta.mainProgram or (lib.getName d)) ] else d.commands;

  featureField = field: concatMap (f: registry.features.${f}.${field} or [ ]) context.features;
  featurePackages = concatMap (f: (registry.features.${f}.deps or (_: [ ])) pkgs) context.features;
in
{
  linkedPath = optionals (!context.standalone) (
    lib.unique (map (p: "${lib.getBin p}/bin") (map packageOf config.deps ++ featurePackages))
  );

  startupCommands = lib.unique (
    config.requires
    ++ optionals context.standalone (
      concatMap commandsOf config.deps
      ++ featureField "commands"
      ++ concatMap (s: s.commands or [ ]) usage.usedFunctions
    )
  );
}
