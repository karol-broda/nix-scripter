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
    lib.optional (a.default != null && a.default != false) (
      if a.kind == "flag" then
        "__scripter_args_default ${a.key} 1"
      else if argument.isList a then
        "__scripter_args_default_list ${a.key} ${lib.escapeShellArgs (lib.toList a.default)}"
      else
        "__scripter_args_default ${a.key} ${q a.default}"
    );

  requiredCheck = a: lib.optional a.required "__scripter_args_require ${a.key} ${q (names.shown a)}";

  constraintChecks =
    level: c:
    let
      byName =
        n: lib.findFirst (a: a.name == n) (throw "unknown argument ${n}") (levels.allArguments level);
      keys = ns: lib.concatMapStringsSep " " (n: (byName n).key) ns;
      shownList = ns: q (lib.concatMapStringsSep ", " (n: "'${names.shown (byName n)}'") ns);
      requires =
        n: dep:
        let
          a = byName n;
          d = byName dep;
        in
        "__scripter_args_requires ${a.key} ${q (names.shown a)} ${d.key} ${q (names.shown d)}";
    in
    lib.optional (
      c.exclusive != null
    ) "__scripter_args_at_most_one ${shownList c.exclusive} ${keys c.exclusive}"
    ++ lib.optional (c.oneOf != null) "__scripter_args_exactly_one ${shownList c.oneOf} ${keys c.oneOf}"
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
  inherit rulesFor;

  finishFunction =
    level:
    let
      rules = rulesFor level;
    in
    lib.optionalString (rules != [ ]) (
      lib.concatStringsSep "\n" ([ "${names.finish level}() {" ] ++ map (r: "  ${r}") rules ++ [ "}" ])
    );
}
