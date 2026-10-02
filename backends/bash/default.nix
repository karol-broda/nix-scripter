{ lib }:
let
  targets = import ./targets.nix;
  scan = import ./scan.nix { inherit lib; };
in
{
  description = "GNU Bash";
  kind = "interpreted";
  extensions = [ "bash" ];

  inherit targets;
  targetOf = config: config.bash.target;
  options = import ./options.nix { inherit targets; };

  scan = scan.namespaced;
  scanBare = scan.bare;
  naming = ns: fn: "${ns}::${fn}";

  argsStyle = target: if lib.elem "assoc-arrays" targets.${target}.caps then "assoc" else "globals";
  argsCodegen = (import ./args { inherit lib; }).codegen;

  testInterpreter = config: "${config.bash.testPackage}/bin/bash";

  inherit (import ./assemble.nix { inherit lib targets; }) assemble;
}
