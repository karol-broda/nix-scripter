{ lib }:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    filter
    optional
    optionalString
    stringLength
    ;
  inherit (import ../lib/util.nix { inherit lib; }) padRight;
  argument = import ./ir/argument.nix { inherit lib; };

  maxLeftColumn = 32;

  table =
    rows:
    let
      fitting = filter (w: w <= maxLeftColumn) (map (r: stringLength r.left) rows);
      column = lib.foldl' lib.max 0 fitting;
      row =
        r:
        if r.right == "" then
          "  ${r.left}"
        else if stringLength r.left > column then
          "  ${r.left}\n  ${padRight column ""}  ${r.right}"
        else
          "  ${padRight column r.left}  ${r.right}";
    in
    concatMapStringsSep "\n" row rows;

  section = title: body: optionalString (body != "") "\n${title}:\n${body}\n";

  showDefault = d: if lib.isList d then concatStringsSep ", " d else d;

  annotations =
    a:
    optional (
      a.values != null && a.kind != "flag"
    ) "[possible values: ${concatStringsSep ", " a.values}]"
    ++ optional (a.default != null && a.kind != "flag") "[default: ${showDefault a.default}]"
    ++ optional (a.env != null) "[env: ${a.env}]"
    ++ optional a.required "[required]";

  describe = a: concatStringsSep " " (filter (s: s != "") ([ a.description ] ++ annotations a));

  optionLabel =
    a:
    let
      short = if a.short != null then "-${a.short}, " else "    ";
      negation = optionalString (a.kind == "flag" && a.negatable) "/--no-${a.long}";
      value = optionalString (argument.takesValue a) (
        " <${a.metavar}>" + optionalString a.repeated "..."
      );
    in
    "${short}--${a.long}${negation}${value}";

  positionalLabel =
    p:
    if p.optional || p.variadic then
      "[${p.metavar}]${optionalString p.variadic "..."}"
    else
      "<${p.metavar}>";

  optionRows = map (a: {
    left = optionLabel a;
    right = describe a;
  });

  positionalRows = map (p: {
    left = positionalLabel p;
    right = describe p;
  });

  commandRows = map (c: {
    left = c.name;
    right =
      c.description + optionalString (c.aliases != [ ]) " [aliases: ${concatStringsSep ", " c.aliases}]";
  });

  builtinRows =
    ir: level:
    optional ir.globals.help {
      left = "-h, --help";
      right = "Print help";
    }
    ++ optional (ir.globals.version && level.isRoot) {
      left = "    --version";
      right = "Print version";
    };

  visible = filter (a: !a.hidden);
  userFirst = args: filter (a: !argument.isGlobal a) args ++ filter argument.isGlobal args;

  usageLine =
    ir: level:
    let
      positionals = concatMapStringsSep " " positionalLabel (visible level.positional);
      hasOptions = level.flags ++ level.options ++ level.inherited != [ ] || ir.globals.help;
    in
    "Usage: ${level.display}"
    + optionalString hasOptions " [OPTIONS]"
    + optionalString (level.commands != [ ]) " <COMMAND>"
    + optionalString (positionals != "") " ${positionals}";

  heading =
    ir: level:
    if level.isRoot then
      "${ir.name} ${ir.version}\n" + optionalString (ir.description != "") "${ir.description}\n" + "\n"
    else
      optionalString (level.description != "") "${level.description}\n\n";

  exampleLines = concatMapStringsSep "\n" (
    e: "  ${e.cmd}" + optionalString (e.description != "") "\n      ${e.description}"
  );

  groupSections =
    level: own:
    lib.concatStrings (
      lib.mapAttrsToList (
        title: names: section title (table (optionRows (filter (a: lib.elem a.name names) own)))
      ) level.groups
    );

  render =
    ir: level:
    let
      own = userFirst (visible (level.flags ++ level.options));
      grouped = lib.concatLists (lib.attrValues level.groups);
      ungrouped = filter (a: !lib.elem a.name grouped) own;
    in
    lib.removeSuffix "\n" (
      heading ir level
      + usageLine ir level
      + "\n"
      + section "Commands" (table (commandRows (filter (c: !c.hidden) level.commands)))
      + section "Arguments" (table (positionalRows (visible level.positional)))
      + section "Options" (table (optionRows ungrouped ++ builtinRows ir level))
      + groupSections level own
      + section "Global options" (table (optionRows (userFirst (visible level.inherited))))
      + section "Examples" (exampleLines level.examples)
    );
in
{
  inherit render;
}
