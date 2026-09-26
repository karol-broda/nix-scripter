{ lib }:
let
  levels = import ../ir/levels.nix { inherit lib; };
  visible = lib.filter (a: !a.hidden);
in
{
  inherit visible;
  inherit (levels) levelsOf commandNames;

  options = level: visible (levels.acceptedOptions level);
  positionals = level: visible level.positional;
  commands = level: lib.filter (c: !c.hidden) level.commands;

  enumValues = lib.concatMap (a: if a.values != null then a.values else [ ]);

  functionName = prog: id: "_${lib.replaceStrings [ "-" "." "+" ] [ "_" "_" "_" ] prog}_${id}";
}
