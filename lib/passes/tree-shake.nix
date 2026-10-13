# Library code is split into top-level items: function definitions and
# everything else. Statements outside functions always stay; a function
# stays when its name appears in a root text, a kept statement or another
# kept function. Relies on functions ending with `}` in column 0.
{ lib }:
let
  functionStart = "([A-Za-z_][A-Za-z0-9_:]*)\\(\\) \\{(.*)";

  startOf =
    line:
    let
      m = builtins.match functionStart line;
    in
    if m == null then
      null
    else
      {
        name = lib.elemAt m 0;
        oneLine = lib.hasSuffix "}" (lib.elemAt m 1);
      };

  emptyState = {
    items = [ ];
    current = null;
    pending = [ ];
  };

  statement = lines: {
    name = null;
    inherit lines;
  };

  step =
    state: line:
    let
      start = startOf line;
      flushPending = lib.optional (state.pending != [ ]) (statement state.pending);
    in
    if state.current != null then
      if line == "}" then
        state
        // {
          items = state.items ++ [ (state.current // { lines = state.current.lines ++ [ line ]; }) ];
          current = null;
        }
      else
        state
        // {
          current = state.current // {
            lines = state.current.lines ++ [ line ];
          };
        }
    else if start != null && start.oneLine then
      state
      // {
        items = state.items ++ [
          {
            inherit (start) name;
            lines = state.pending ++ [ line ];
          }
        ];
        pending = [ ];
      }
    else if start != null then
      state
      // {
        current = {
          inherit (start) name;
          lines = state.pending ++ [ line ];
        };
        pending = [ ];
      }
    else if lib.hasPrefix "#" line then
      state // { pending = state.pending ++ [ line ]; }
    else
      state
      // {
        items = state.items ++ flushPending ++ [ (statement [ line ]) ];
        pending = [ ];
      };

  itemsOf =
    code:
    let
      final = lib.foldl' step emptyState (lib.splitString "\n" code);
    in
    final.items ++ lib.optional (final.pending != [ ]) (statement final.pending);

  tokensOf =
    text:
    lib.listToAttrs (
      map (t: lib.nameValuePair t true) (lib.filter lib.isString (builtins.split "[^A-Za-z0-9_:]+" text))
    );

  referencedBy = names: text: lib.filter (n: (tokensOf text) ? ${n}) names;
in
{
  shake =
    {
      features,
      roots,
      keep,
    }:
    let
      parsed = map (f: f // { items = itemsOf f.code; }) features;
      allItems = lib.concatMap (f: f.items) parsed;
      functions = lib.filter (i: i.name != null) allItems;
      names = lib.unique (map (i: i.name) functions);
      bodies = lib.foldl' (
        acc: i: acc // { ${i.name} = (acc.${i.name} or "") + lib.concatStringsSep "\n" i.lines; }
      ) { } functions;
      statements = lib.concatMapStringsSep "\n" (i: lib.concatStringsSep "\n" i.lines) (
        lib.filter (i: i.name == null) allItems
      );
      rootNames =
        referencedBy names (lib.concatStringsSep "\n" (roots ++ [ statements ]))
        ++ lib.filter (n: lib.elem n names) keep;
      reachable = lib.listToAttrs (
        map (e: lib.nameValuePair e.key true) (
          builtins.genericClosure {
            startSet = map (n: { key = n; }) rootNames;
            operator = e: map (n: { key = n; }) (referencedBy names bodies.${e.key});
          }
        )
      );
      keepItem = i: i.name == null || reachable ? ${i.name};
      render =
        items:
        lib.concatMapStringsSep "\n" (i: lib.concatStringsSep "\n" i.lines) (lib.filter keepItem items);
    in
    map (f: {
      inherit (f) name;
      code = render f.items;
    }) parsed;
}
