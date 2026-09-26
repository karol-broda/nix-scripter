{ lib }:
let
  inherit (lib) concatStringsSep filterAttrs mapAttrsToList;
  argument = import ./argument.nix { inherit lib; };
  naming = import ./naming.nix { inherit lib; };
  util = import ../../lib/util.nix { inherit lib; };

  bodyOf =
    spec: path:
    if spec.text != null then
      {
        inherit (spec) text;
        file = "${concatStringsSep "." ([ "commands" ] ++ path)}.text";
      }
    else if spec.src != null then
      {
        text = builtins.readFile spec.src;
        file = baseNameOf spec.src;
      }
    else
      null;

  boolOptions = filterAttrs (_: o: o.type == "bool");
  valuedOptions = filterAttrs (_: o: o.type != "bool");

  mkLevel =
    {
      spec,
      path,
      prog,
      negatableDefault,
      inherited,
      globals,
    }:
    let
      flags =
        mapAttrsToList (argument.flag negatableDefault) spec.flags
        ++ mapAttrsToList (argument.option negatableDefault) (boolOptions spec.options)
        ++ lib.filter (a: a.kind == "flag") globals;
      options =
        mapAttrsToList (argument.option negatableDefault) (valuedOptions spec.options)
        ++ lib.filter (a: a.kind == "option") globals;
      inheritedHere = if path == [ ] || spec.inheritGlobals then inherited else [ ];
    in
    {
      inherit path flags options;
      id = concatStringsSep "__" ([ "root" ] ++ map naming.sanitize path);
      display = concatStringsSep " " ([ prog ] ++ path);
      name = if path == [ ] then prog else lib.last path;
      isRoot = path == [ ];
      inherit (spec)
        description
        aliases
        hidden
        groups
        ;
      examples = map util.withoutModuleAttrs spec.examples;
      positional = map argument.positional spec.positional;
      inherited = inheritedHere;
      constraints = map (c: { inherit (c) exclusive requires oneOf; }) spec.constraints;
      body = bodyOf spec path;
      commands = mapAttrsToList (
        name: sub:
        mkLevel {
          spec = sub;
          path = path ++ [ name ];
          inherit prog negatableDefault;
          inherited = inheritedHere ++ flags ++ options;
          globals = [ ];
        }
      ) spec.commands;
    };

  levelsOf = level: [ level ] ++ lib.concatMap levelsOf level.commands;

  ownArguments = level: level.flags ++ level.options ++ level.positional;
  acceptedOptions = level: level.inherited ++ level.flags ++ level.options;
  allArguments = level: level.inherited ++ ownArguments level;
  commandNames = level: [ level.name ] ++ level.aliases;
in
{
  inherit
    mkLevel
    levelsOf
    ownArguments
    acceptedOptions
    allArguments
    commandNames
    ;
}
