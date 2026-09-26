# Values are parsed into internal variables and only exported in the
# configured style at the end, so the parser itself is plain bash 3.2.
{ lib }:
let
  help = import ../../../args/help.nix { inherit lib; };
  levels = import ../../../args/ir/levels.nix { inherit lib; };
  inherit (import ../../../lib/util.nix { inherit lib; }) joinLines;
  inherit (import ./setters.nix { inherit lib; }) setterFunction;
  inherit (import ./parse.nix { inherit lib; }) parseFunction helpFunction;
  inherit (import ./finish.nix { inherit lib; }) finishFunction;
  output = import ./output.nix { inherit lib; };
  commands = import ./dispatch.nix { inherit lib; };

  uniqueByKey =
    arguments: lib.attrValues (lib.listToAttrs (map (a: lib.nameValuePair a.key a) arguments));

  levelFunctions =
    ir: level:
    joinLines [
      (helpFunction (help.render ir level) level)
      (parseFunction ir level)
      (finishFunction level)
    ];
in
{
  codegen =
    { ir }:
    let
      allLevels = levels.levelsOf ir.root;
      arguments = uniqueByKey (lib.concatMap levels.ownArguments allLevels);
    in
    {
      parser = joinLines [
        (builtins.readFile ./runtime.bash)
        (joinLines (map setterFunction (lib.filter (a: a.kind != "flag") arguments)))
        (joinLines (map (levelFunctions ir) allLevels))
        (output.variables ir.vars arguments)
        (output.exportFunction ir.vars arguments)
      ];

      invoke = ''
        __scripter_args_parse_root "$@"
        __scripter_args_export'';

      dispatch = commands.dispatch ir allLevels;
      bodies = commands.bodies allLevels;
      dump = output.dump arguments;
    };

}
