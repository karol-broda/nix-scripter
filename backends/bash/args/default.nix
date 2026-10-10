# Values are parsed into internal variables and only exported in the
# configured style at the end, so the parser itself is plain bash 3.2.
{ lib }:
let
  help = import ../../../args/help.nix { inherit lib; };
  levels = import ../../../args/ir/levels.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };
  inherit (import ../../../lib/util.nix { inherit lib; }) joinLines readFiles;
  inherit (import ./setters.nix { inherit lib; }) setterFunction;
  inherit (import ./tables.nix { inherit lib; }) tablesFor;
  inherit (import ./parse.nix { inherit lib; }) parseFunction helpFunction;
  inherit (import ./finish.nix { inherit lib; }) finishFunction;
  output = import ./output.nix { inherit lib; };
  commands = import ./dispatch.nix { inherit lib; };

  uniqueByKey =
    arguments: lib.attrValues (lib.listToAttrs (map (a: lib.nameValuePair a.key a) arguments));

  # Subcommands that inherit the same options share one "Global options" section.
  sharedHelpSections =
    ir: allLevels:
    let
      texts = lib.unique (
        lib.filter (t: t != "") (map (level: (help.parts ir level).inherited) allLevels)
      );
      indexOf = text: lib.lists.findFirstIndex (t: t == text) null texts;
      nameOf = text: "__scripter_args_help_section_${toString (indexOf text)}";
      sectionFunction = text: ''
        ${nameOf text}() {
          printf '%s' ${lib.escapeShellArg text}
        }'';
    in
    {
      inherit nameOf;
      code = joinLines (map sectionFunction texts);
    };

  # Only the runtime pieces this parser can reach are included.
  runtimeFiles =
    ir: allLevels:
    let
      arguments = lib.concatMap levels.ownArguments allLevels;
      anyArgument = pred: lib.any pred arguments;
      anyLevel = pred: lib.any pred allLevels;
      piece = name: ./runtime + "/${name}.bash";
    in
    map piece (
      [
        "errors"
        "values"
        "parse"
      ]
      ++ lib.optional (anyArgument (a: a.values != null)) "enum"
      ++ lib.optional ir.hasCommands "commands"
      ++ lib.optional (anyLevel (l: !l.isRoot && l.commands == [ ] && l.body == null)) "implementation"
      ++ lib.optional (anyArgument (a: a.env != null)) "env"
      ++ lib.optional (anyArgument (a: a.default != null && a.default != false)) "defaults"
      ++ lib.optional (anyArgument (a: a.required)) "required"
      ++ lib.optional (anyLevel (l: l.constraints != [ ])) "constraints"
      ++ lib.optional (anyArgument argument.isGlobal) "globals"
    );

  setters =
    level: map (setterFunction level) (lib.filter (a: a.kind != "flag") (levels.ownArguments level));

  levelCode =
    ir: allLevels: sections: level:
    joinLines (
      lib.filter (s: s != "") (
        [ (tablesFor level) ]
        ++ setters level
        ++ [
          (helpFunction {
            parts = help.parts ir level;
            sharedSection = sections.nameOf;
          } level)
          (parseFunction allLevels level)
          (finishFunction level)
        ]
      )
    );
in
{
  codegen =
    { ir }:
    let
      allLevels = levels.levelsOf ir.root;
      arguments = uniqueByKey (lib.concatMap levels.ownArguments allLevels);
      sections = sharedHelpSections ir allLevels;
    in
    {
      parser = joinLines (
        lib.filter (s: s != "") [
          (readFiles (runtimeFiles ir allLevels))
          sections.code
          (joinLines (map (levelCode ir allLevels sections) allLevels))
          (output.variables ir arguments)
          (output.exportFunction ir.vars arguments)
        ]
      );

      invoke = ''
        __scripter_args_parse_root "$@"
        __scripter_args_export'';

      dispatch = commands.dispatch ir allLevels;
      bodies = commands.bodies allLevels;
      dump = output.dump arguments;
    };
}
