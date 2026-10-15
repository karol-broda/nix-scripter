{ lib }:
let
  inherit (lib) concatStringsSep optional optionalString;
  q = lib.escapeShellArg;
  levels = import ../../../args/ir/levels.nix { inherit lib; };

  kindOf =
    a:
    if a.kind == "option" then
      "option"
    else if a.count then
      "count"
    else
      "flag";

  isNegatable = a: a.kind == "flag" && a.negatable;
  optionsOf = level: level.flags ++ level.options;

  spellings =
    a:
    [ "--${a.long}" ]
    ++ optional (a.short != null) "-${a.short}"
    ++ optional (isNegatable a) "--no-${a.long}";

  lookupFields = kind: a: "__scripter_args_kind=${kind} __scripter_args_key=${a.key}";

  lookupBranches =
    a:
    [
      {
        patterns = [ "--${a.long}" ] ++ optional (a.short != null) "-${a.short}";
        body = lookupFields (kindOf a) a;
      }
    ]
    ++ optional (isNegatable a) {
      patterns = [ "--no-${a.long}" ];
      body = lookupFields "no${kindOf a}" a;
    };

  caseFunction =
    name: branches:
    concatStringsSep "\n" (
      [
        "${name}() {"
        "  case $1 in"
      ]
      ++ map (b: "    ${concatStringsSep " | " b.patterns}) ${b.body} ;;") branches
      ++ [
        "    *) return 1 ;;"
        "  esac"
        "}"
      ]
    );

  optionLookup =
    level:
    optionalString (optionsOf level != [ ]) (
      caseFunction "__scripter_args_lookup_${level.id}" (lib.concatMap lookupBranches (optionsOf level))
      + "\n__scripter_args_longs_${level.id}=${
        q (
          concatStringsSep " " (
            lib.concatMap (a: lib.filter (lib.hasPrefix "--") (spellings a)) (optionsOf level)
          )
        )
      }"
    );

  positionalMode =
    p:
    if p.variadic then
      "variadic"
    else if p.optional then
      "optional"
    else
      "required";

  positionalTable =
    level:
    optionalString (level.positional != [ ])
      "__scripter_args_positionals_${level.id}=(${
        concatStringsSep " " (map (p: q "${p.key} ${positionalMode p} <${p.name}>") level.positional)
      })";

  commandLookup =
    level:
    optionalString (level.commands != [ ]) (
      concatStringsSep "\n" [
        (caseFunction "__scripter_args_commands_${level.id}" (
          map (sub: {
            patterns = map q (levels.commandNames sub);
            body = "__scripter_args_row=${q "${sub.id} ${concatStringsSep " " sub.path}"}";
          }) level.commands
        ))
        "__scripter_args_words_${level.id}=${q (concatStringsSep " " (lib.concatMap levels.commandNames level.commands))}"
        "__scripter_args_names_${level.id}=${q (concatStringsSep ", " (map (c: c.name) level.commands))}"
      ]
    );
in
{
  tablesFor =
    level:
    concatStringsSep "\n" (
      lib.filter (s: s != "") [
        (optionLookup level)
        (positionalTable level)
        (commandLookup level)
      ]
    );

  # Levels whose options apply: the level itself, then its ancestors for as
  # long as each step inherits the parent's options. Levels without options
  # are skipped.
  optionLevels =
    allLevels: level:
    let
      parentOf = l: lib.findFirst (p: p.path == lib.init l.path) null allLevels;
      chain =
        l:
        [ l ] ++ lib.optionals (!l.isRoot && l.inherited != [ ] && parentOf l != null) (chain (parentOf l));
    in
    concatStringsSep " " (map (l: l.id) (lib.filter (l: optionsOf l != [ ]) (chain level)));
}
