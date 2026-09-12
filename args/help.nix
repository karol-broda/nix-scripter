# Renders `--help` text for one level of the IR. Plain text, generated at
# build time; backends only print it.
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

  pad = n: s: s + lib.concatStrings (lib.genList (_: " ") (n - stringLength s));

  maxCol = 32;

  table =
    rows:
    let
      width = lib.foldl' lib.max 0 (map (r: stringLength r.left) rows);
      col = lib.min maxCol width;
    in
    concatMapStringsSep "\n" (
      r:
      if r.right == "" then
        "  ${r.left}"
      else if stringLength r.left > col then
        "  ${r.left}\n  ${pad col ""}  ${r.right}"
      else
        "  ${pad col r.left}  ${r.right}"
    ) rows;

  annotations =
    a:
    concatStringsSep " " (
      optional (
        a.values or null != null && a.kind != "flag"
      ) "[possible values: ${concatStringsSep ", " a.values}]"
      ++ optional (a.default or null != null && a.kind != "flag") (
        "[default: ${if lib.isList a.default then concatStringsSep ", " a.default else a.default}]"
      )
      ++ optional (a.env or null != null) "[env: ${a.env}]"
      ++ optional (a.required or false) "[required]"
    );

  describe =
    a:
    let
      ann = annotations a;
    in
    concatStringsSep " " (
      filter (s: s != "") [
        a.description
        ann
      ]
    );

  argLeft =
    a:
    let
      short = if a.short or null != null then "-${a.short}, " else "    ";
      value = if a.kind == "option" then " <${a.metavar}>" + optionalString a.repeated "..." else "";
      neg = optionalString (a.kind == "flag" && a.negatable) "/--no-${a.long}";
    in
    "${short}--${a.long}${neg}${value}";

  posLeft =
    p:
    if p.optional || p.variadic then
      "[${p.metavar}]${optionalString p.variadic "..."}"
    else
      "<${p.metavar}>";

  builtinRows =
    ir: level:
    optional ir.globals.help {
      left = "-h, --help";
      right = "Print help";
    }
    ++ optional (ir.globals.version && level.path == [ ]) {
      left = "    --version";
      right = "Print version";
    };

  section = title: body: optionalString (body != "") "\n${title}:\n${body}\n";

  render =
    ir: level:
    let
      visible = filter (a: !a.hidden);
      # user arguments first, then the library's global flags
      own =
        let
          all = visible (level.flags ++ level.options);
        in
        filter (a: a.action == null) all ++ filter (a: a.action != null) all;
      inherited = visible level.inherited;
      grouped = lib.concatLists (lib.attrValues level.groups);
      ungrouped = filter (a: !lib.elem a.name grouped) own;
      positional = visible level.positional;
      commands = filter (c: !c.hidden) level.commands;
      usagePositional = concatMapStringsSep " " posLeft positional;
      usage =
        "Usage: ${level.display}"
        + optionalString (own != [ ] || inherited != [ ] || ir.globals.help) " [OPTIONS]"
        + optionalString (commands != [ ]) " <COMMAND>"
        + optionalString (usagePositional != "") " ${usagePositional}";
      rows = map (a: {
        left = argLeft a;
        right = describe a;
      });
      groupSections = lib.concatStrings (
        lib.mapAttrsToList (
          title: names: section title (table (rows (filter (a: lib.elem a.name names) own)))
        ) level.groups
      );
      description = optionalString (level.description != "") "${level.description}\n\n";
      header = optionalString (level.path == [ ]) (
        "${ir.name} ${ir.version}\n" + optionalString (ir.description != "") "${ir.description}\n" + "\n"
      );
    in
    lib.removeSuffix "\n" (
      (if level.path == [ ] then header else description)
      + usage
      + "\n"
      + section "Commands" (
        table (
          map (c: {
            left = c.name;
            right =
              c.description + optionalString (c.aliases != [ ]) " [aliases: ${concatStringsSep ", " c.aliases}]";
          }) commands
        )
      )
      + section "Arguments" (
        table (
          map (p: {
            left = posLeft p;
            right = describe p;
          }) positional
        )
      )
      + section "Options" (table (rows ungrouped ++ builtinRows ir level))
      + groupSections
      + section "Global options" (table (rows inherited))
      + section "Examples" (
        concatMapStringsSep "\n" (
          e: "  ${e.cmd}" + optionalString (e.description != "") "\n      ${e.description}"
        ) level.examples
      )
    );
in
{
  inherit render;
}
