{ lib }:
let
  argument = import ./argument.nix { inherit lib; };
  globals = import ./globals.nix { inherit lib; };
  levels = import ./levels.nix { inherit lib; };
  naming = import ./naming.nix { inherit lib; };
  inherit (import ./validate.nix { inherit lib; }) validate;
  util = import ../../lib/util.nix { inherit lib; };

  irVersion = 1;

  build =
    {
      name,
      version,
      description,
      spec,
      style,
    }:
    let
      root = levels.mkLevel {
        inherit spec;
        path = [ ];
        prog = name;
        negatableDefault = spec.defaults.negatable;
        inherited = [ ];
        globals = globals.enabled spec.globals;
      };
      vars = util.withoutModuleAttrs spec.vars // {
        inherit style;
      };
      allLevels = levels.levelsOf root;
    in
    {
      ir = {
        inherit
          irVersion
          name
          version
          description
          root
          vars
          ;
        globals = { inherit (spec.globals) help version; };
        levels = allLevels;
        hasCommands = root.commands != [ ];
        tests = map util.withoutModuleAttrs spec.tests;
      };
      errors = validate vars allLevels;
    };
in
{
  inherit
    build
    irVersion
    argument
    levels
    naming
    ;
}
