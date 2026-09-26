{ lib }:
let
  inherit (lib)
    concatMap
    concatStringsSep
    filter
    length
    optional
    ;
  inherit (import ../../lib/util.nix { inherit lib; }) duplicates;
  naming = import ./naming.nix { inherit lib; };
  levels = import ./levels.nix { inherit lib; };

  locationOf =
    level: if level.isRoot then "args" else "args.commands.${concatStringsSep ".commands." level.path}";

  indexOfFirst =
    pred: xs: lib.findFirst (i: pred (lib.elemAt xs i)) null (lib.range 0 (length xs - 1));

  orEmpty = x: if x == null then [ ] else x;

  constraintNames =
    c:
    orEmpty c.exclusive
    ++ orEmpty c.oneOf
    ++ lib.optionals (c.requires != null) (
      lib.attrNames c.requires ++ lib.concatLists (lib.attrValues c.requires)
    );

  duplicateLongs =
    level:
    map (d: "duplicate long option `--${d}`") (
      duplicates (
        map (a: a.long) (levels.acceptedOptions level) ++ [ "help" ] ++ optional level.isRoot "version"
      )
    );

  duplicateShorts =
    level:
    map (d: "duplicate short option `-${d}`") (
      duplicates (filter (s: s != null) (map (a: a.short) (levels.acceptedOptions level)) ++ [ "h" ])
    );

  duplicateKeys =
    level:
    map (d: "argument key `${d}` is used twice (keys must be unique along a command path)") (
      duplicates (map (a: a.key) (levels.allArguments level))
    );

  positionalsWithCommands =
    level:
    optional (
      level.positional != [ ] && level.commands != [ ]
    ) "a level cannot have both positional arguments and commands";

  variadicNotLast =
    level:
    let
      i = indexOfFirst (p: p.variadic) level.positional;
    in
    optional (
      i != null && i != length level.positional - 1
    ) "only the last positional argument can be variadic";

  requiredAfterOptional =
    level:
    let
      i = indexOfFirst (p: p.optional) level.positional;
    in
    optional (
      i != null && lib.any (p: !p.optional && !p.variadic) (lib.drop i level.positional)
    ) "required positional arguments cannot follow optional ones";

  enumWithoutValues =
    a: optional (a.type == "enum" && a.values == null) "`${a.name}` has type enum but no `values`";

  defaultNotAllowed =
    a:
    optional (
      a.values != null && a.default != null && lib.any (d: !lib.elem d a.values) (lib.toList a.default)
    ) "default of `${a.name}` is not one of ${builtins.toJSON a.values}";

  listDefaultOnScalar =
    a:
    optional (
      lib.isList a.default && !(a.repeated || a.variadic)
    ) "`${a.name}` has a list default but is not repeated or variadic";

  invalidValues =
    level:
    concatMap (a: enumWithoutValues a ++ defaultNotAllowed a ++ listDefaultOnScalar a) (
      filter (a: a.kind != "flag") (levels.ownArguments level)
    );

  unknownNames =
    what: names: level:
    let
      known = map (a: a.name) (levels.allArguments level);
    in
    map (n: "${what} refers to unknown argument `${n}`") (
      filter (n: !lib.elem n known) (lib.unique names)
    );

  unknownConstraintNames =
    level: unknownNames "constraint" (concatMap constraintNames level.constraints) level;
  unknownGroupNames =
    level: unknownNames "group" (lib.concatLists (lib.attrValues level.groups)) level;

  invalidKeys =
    level:
    map (a: "`${a.name}` gives the invalid key `${a.key}`; set `var`") (
      filter (a: !naming.isIdentifier a.key) (levels.ownArguments level)
    );

  shadowedShellVariables =
    vars: level:
    lib.optionals (vars.style == "globals") (
      map
        (a: "`${a.name}` would overwrite the shell variable `${naming.globalVariable vars a}`; set `var`")
        (
          filter (a: lib.elem (naming.globalVariable vars a) naming.shellSpecials) (levels.ownArguments level)
        )
    );

  levelChecks = vars: [
    duplicateLongs
    duplicateShorts
    duplicateKeys
    positionalsWithCommands
    variadicNotLast
    requiredAfterOptional
    invalidValues
    unknownConstraintNames
    unknownGroupNames
    invalidKeys
    (shadowedShellVariables vars)
  ];

  validateLevel =
    vars: level:
    map (e: "${locationOf level}: ${e}") (concatMap (check: check level) (levelChecks vars));

  variableCollisions =
    vars: allLevels:
    let
      keyToVariable = lib.unique (
        concatMap (
          level:
          map (a: {
            inherit (a) key;
            var = naming.globalVariable vars a;
          }) (levels.ownArguments level)
        ) allLevels
      );
    in
    lib.optionals (vars.style == "globals") (
      map (d: "args: several arguments map to the variable `${d}`; set `var`") (
        duplicates (map (kv: kv.var) keyToVariable)
      )
    );

  invalidVariableName =
    vars:
    optional (!naming.isIdentifier vars.name) "args.vars.name `${vars.name}` is not a valid identifier";
in
{
  validate =
    vars: allLevels:
    lib.unique (concatMap (validateLevel vars) allLevels)
    ++ variableCollisions vars allLevels
    ++ invalidVariableName vars;
}
