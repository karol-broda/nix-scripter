{
  lib,
  pkgs,
  registry,
  config,
  context,
  cli,
  files,
}:
let
  driver = import ../checkers/driver.nix { inherit lib pkgs; };

  appliesToScript =
    name: checker:
    config.check.enable
    && config.check.${name}.enable
    && lib.elem config.lang (checker.backends or [ ]);

  active = lib.filterAttrs appliesToScript registry.checkers;
  atStage = stage: lib.filterAttrs (name: _: config.check.${name}.stage == stage) active;

  run =
    name: checker:
    driver.run {
      script = context.name;
      checkerName = name;
      inherit checker config files;
      cfg = config.check.${name};
    };

  asDerivation =
    name: checker:
    let
      r = run name checker;
    in
    pkgs.runCommandLocal "${context.name}-check-${name}" { nativeBuildInputs = r.packages; } ''
      ${r.script}
      touch $out
    '';

  argsTests = import ./args-tests.nix {
    inherit lib pkgs config;
    inherit (context) name backend;
    inherit (cli) ir code;
  };
in
{
  build = lib.mapAttrsToList run (atStage "build");

  derivations =
    lib.mapAttrs asDerivation (atStage "flake-check")
    // lib.optionalAttrs (cli.enable && cli.ir.tests != [ ]) { args = argsTests; };
}
