{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  levels = import ../../../args/ir/levels.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };

  unlessGiven = a: rule: "${names.isGiven a} || ${rule}";
  envSet = a: "[ -z \"\${${a.env}:-}\" ]";

  envFallback =
    level: a:
    lib.optional (a.env != null) (
      unlessGiven a (
        "${envSet a} || "
        + (
          if a.kind == "flag" then
            "__scripter_args_flag_from_env ${a.key} ${a.env} ${if a.count then "count" else "flag"}"
          else
            "${names.setter level a} \"\$${a.env}\" \"\\\$${a.env}\""
        )
      )
    );

  defaultValue =
    a:
    lib.optional (a.default != null && a.default != false) (
      unlessGiven a (
        if a.kind == "flag" then
          "${names.value a.key}=1"
        else if argument.isList a then
          "${names.list a.key}=(${lib.escapeShellArgs (lib.toList a.default)})"
        else
          "${names.value a.key}=${q a.default}"
      )
    );

  requiredCheck =
    a:
    lib.optional a.required (
      unlessGiven a "__scripter_args_error ${q "missing required option '${names.shown a}'"}"
    );

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

  globalExports = {
    verbose = "SCRIPTER_LOG_LEVEL=debug";
    quiet = "SCRIPTER_LOG_LEVEL=warn";
    yes = "SCRIPTER_YES=1";
    dryRun = "SCRIPTER_DRY_RUN=1";
    color = "SCRIPTER_COLOR=\"\$${names.value "color"}\"";
  };

  globalAction =
    a:
    let
      unset =
        if a.count then
          "[ \"\${${names.value a.key}:-0}\" = 0 ]"
        else
          "[ -z \"\${${names.value a.key}:-}\" ]";
    in
    lib.optional (argument.isGlobal a) "${unset} || export ${globalExports.${a.action}}";

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
