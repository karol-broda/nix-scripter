{
  lib,
  pkgs,
  registry,
  config,
  extend,
}:
let
  util = import ../util.nix { inherit lib; };

  context = import ./context.nix { inherit lib registry config; };
  cli = import ./cli.nix { inherit lib config context; };
  usage = import ./usage.nix {
    inherit
      lib
      registry
      config
      context
      cli
      ;
  };
  dependencies = import ./dependencies.nix {
    inherit
      lib
      pkgs
      registry
      config
      context
      usage
      ;
  };

  featureCode =
    featureName:
    let
      impl =
        registry.features.${featureName}.impl.${config.lang}
          or (throw "${context.name}: feature ${featureName} has no ${config.lang} implementation");
    in
    {
      name = featureName;
      code = impl {
        cfg = config.features.${featureName};
        inherit config;
        inherit (context) caps target;
        args = if cli.enable then cli.ir else null;
      };
    };

  segments = context.backend.assemble {
    inherit config;
    inherit (dependencies) linkedPath startupCommands;
    inherit (context) user;
    features = map featureCode context.features;
    args = if cli.enable then { inherit (cli) ir code; } else null;
  };

  layout = import ./layout.nix {
    inherit lib;
    inherit (context) name;
  } segments;

  files = {
    source = pkgs.writeTextFile {
      name = "${context.name}-source";
      text = layout.source;
      executable = true;
    };
    sourceMap = pkgs.writeText "${context.name}-sourcemap.json" (builtins.toJSON layout.sourceMap);
    userSource = pkgs.writeText "${context.name}-user-source" context.user.text;
  };

  checks = import ./checks.nix {
    inherit
      lib
      pkgs
      registry
      config
      context
      cli
      files
      ;
  };

  package = import ./package.nix {
    inherit
      lib
      pkgs
      config
      context
      cli
      files
      checks
      layout
      extend
      ;
  };

  errors =
    map (a: a.message) (lib.filter (a: !a.assertion) config.assertions) ++ cli.errors ++ usage.errors;
in
if errors == [ ] then
  package
else
  throw "nix-scripter: script `${context.name}` has errors:\n${util.bulletList errors}"
