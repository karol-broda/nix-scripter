{
  lib,
  registry,
  config,
}:
let
  backend = registry.backends.${config.lang};
  target = backend.targetOf config;

  enabledFeatures = lib.attrNames (
    lib.filterAttrs (_: f: f.enable) (removeAttrs config.features [ "_module" ])
  );

  requires = a: b: lib.elem a (registry.features.${b}.requires or [ ]);
in
{
  inherit (config) name;
  inherit backend target;
  caps = backend.targets.${target}.caps;
  standalone = config.mode == "standalone";

  user =
    if config.text != null then
      {
        inherit (config) text;
        file = "<${config.name}>";
      }
    else
      {
        text = builtins.readFile config.src;
        file = baseNameOf config.src;
      };

  features = (lib.toposort requires enabledFeatures).result;
}
