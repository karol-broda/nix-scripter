{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  levels = import ../../../args/ir/levels.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };

  envKind =
    a:
    if a.kind != "flag" then
      "option"
    else if a.count then
      "count"
    else
      "flag";

  envFallback =
    level: a:
    lib.optional (a.env != null) (
      "__scripter_args_from_env ${a.key} ${a.env} ${envKind a}"
      + lib.optionalString (a.kind != "flag") " ${names.setter level a}"
    );

  defaultValue =
    a:
    let
      shape = if argument.isList a then "list" else "scalar";
      values = if a.kind == "flag" then [ "1" ] else lib.toList a.default;
    in
    lib.optional (
      a.default != null && a.default != false
    ) "__scripter_args_default ${a.key} ${shape} ${lib.escapeShellArgs values}";

  requiredCheck = a: lib.optional a.required "__scripter_args_require ${a.key} ${q (names.shown a)}";

  constraintChecks =
    level: c:
    let
      byName =
        n: lib.findFirst (a: a.name == n) (throw "unknown argument ${n}") (levels.allArguments level);
      keys = ns: lib.concatMapStringsSep " " (n: (byName n).key) ns;
      shownList = ns: q (lib.concatMapStringsSep ", " (n: "'${names.shown (byName n)}'") ns);
      limit = op: ns: "__scripter_args_limit ${op} ${shownList ns} ${keys ns}";
      requires =
        n: dep:
        let
          a = byName n;
          d = byName dep;
        in
        "__scripter_args_requires ${a.key} ${q (names.shown a)} ${d.key} ${q (names.shown d)}";
    in
    lib.optional (c.exclusive != null) (limit "le" c.exclusive)
    ++ lib.optional (c.oneOf != null) (limit "eq" c.oneOf)
    ++ lib.optionals (c.requires != null) (
      lib.concatLists (lib.mapAttrsToList (n: deps: map (requires n) deps) c.requires)
    );

  globalAction =
    a: lib.optional (argument.isGlobal a) "__scripter_args_apply_global ${a.action} ${a.key}";

  rulesFor =
    level:
    let
      own = levels.ownArguments level;
    in
    lib.concatMap (envFallback level) own
    ++ lib.concatMap defaultValue own
    ++ lib.concatMap requiredCheck own
    ++ lib.concatMap (constraintChecks level) level.constraints
    ++ lib.concatMap globalAction own;
in
{
  finishFunction =
    level:
    let
      rules = rulesFor level;
    in
    lib.optionalString (rules != [ ]) (
      lib.concatStringsSep "\n" ([ "${names.finish level}() {" ] ++ map (r: "  ${r}") rules ++ [ "}" ])
    );
}
