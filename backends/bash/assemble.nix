# Produces the ordered segments of a script. A segment is
#   { kind = "generated" | "library" | "user"; label; file?; text; }
# or, when its content depends on the final layout, { …; lines; render; }.
{ lib, targets }:
let
  q = lib.escapeShellArg;
  prelude = import ./prelude.nix { inherit lib targets; };

  generated = label: text: {
    kind = "generated";
    inherit label text;
  };

  userCode = file: text: {
    kind = "user";
    inherit file text;
    label = file;
  };

  isUser = s: s.kind == "user";

  # Read by core's error reporting to map line numbers back to user files.
  # Its line count is known up front so the layout can be computed first.
  runtimeSourceMap = body: {
    kind = "generated";
    label = "source map";
    lines = 2 + lib.length (lib.filter isUser body);
    render =
      layout:
      lib.concatStringsSep "\n" (
        [ "__scripter_srcmap=(" ]
        ++ map (s: "  ${q "${toString s.start} ${toString s.end} ${s.file}"}") (lib.filter isUser layout)
        ++ [ ")" ]
      );
  };

  commandBody =
    b:
    let
      label = "command ${lib.concatStringsSep " " b.path}";
    in
    [
      (generated label "${b.name}() {")
      (userCode b.file b.text)
      (generated label "}")
    ];

  librarySegment = f: {
    kind = "library";
    label = "feature ${f.name}";
    text = f.code;
  };
in
{
  assemble =
    {
      config,
      features,
      args,
      linkedPath,
      startupCommands,
      user,
    }:
    let
      parser = lib.optionals (args != null) [ (generated "argument parser" args.code.parser) ];
      bodies = lib.optionals (args != null) (lib.concatMap commandBody args.code.bodies);
      invoke = lib.optionals (args != null) [ (generated "argument parser" args.code.invoke) ];
      dispatch = lib.optionals (args != null && args.code.dispatch != "") [
        (generated "command dispatch" args.code.dispatch)
      ];
      body =
        map librarySegment features
        ++ parser
        ++ bodies
        ++ invoke
        ++ [ (userCode user.file user.text) ]
        ++ dispatch;
      usesCore = lib.any (f: f.name == "core") features;
    in
    [
      (generated "prelude" (prelude.render { inherit config linkedPath startupCommands; }))
    ]
    ++ lib.optional usesCore (runtimeSourceMap body)
    ++ body;
}
