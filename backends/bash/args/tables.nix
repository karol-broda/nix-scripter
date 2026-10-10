{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  levels = import ../../../args/ir/levels.nix { inherit lib; };

  kindOf =
    a:
    if a.kind == "option" then
      "option"
    else if a.count then
      "count"
    else
      "flag";

  optionRow =
    a:
    lib.concatStringsSep " " [
      a.long
      (if a.short != null then a.short else "-")
      (kindOf a)
      (if a.negatable then "1" else "0")
      a.key
    ];

  positionalMode =
    p:
    if p.variadic then
      "variadic"
    else if p.optional then
      "optional"
    else
      "required";

  positionalRow = p: "${p.key} ${positionalMode p} <${p.name}>";

  commandRows =
    sub: map (word: "${word} ${sub.id} ${lib.concatStringsSep " " sub.path}") (levels.commandNames sub);

  table =
    kind: level: rows:
    lib.optionalString (rows != [ ]) "${names.table kind level}=${q (lib.concatStringsSep "\n" rows)}";
in
{
  tablesFor =
    level:
    lib.concatStringsSep "\n" (
      lib.filter (s: s != "") [
        (table "options" level (map optionRow (level.flags ++ level.options)))
        (table "positionals" level (map positionalRow level.positional))
        (table "commands" level (lib.concatMap commandRows level.commands))
      ]
    );

  # Levels whose option tables apply: the level itself, then its ancestors
  # for as long as each step inherits the parent's options.
  optionLevels =
    allLevels: level:
    let
      parentOf = l: lib.findFirst (p: p.path == lib.init l.path) null allLevels;
      chain =
        l:
        [ l.id ]
        ++ lib.optionals (!l.isRoot && l.inherited != [ ] && parentOf l != null) (chain (parentOf l));
    in
    lib.concatStringsSep " " (chain level);
}
