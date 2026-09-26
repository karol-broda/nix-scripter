{ lib }:
let
  inherit (lib) concatMapStringsSep optionalString;
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  levels = import ../../../args/ir/levels.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };

  notGiven = a: "[ -z ${names.givenRef a} ]";
  envSet = a: "[ -n \"\${${a.env}:-}\" ]";
  envValue = a: "\"\$${a.env}\"";
  envShown = a: "\"\\\$${a.env}\"";

  flagFromEnv =
    cmd: a:
    if a.count then
      ''
        __scripter_args_check int ${envValue a} ${envShown a} ${cmd} ""
        ${names.value a.key}=${envValue a}''
    else
      ''
        __scripter_args_bool ${envValue a} ${envShown a} ${cmd}
        ${names.value a.key}=$__scripter_args_b'';

  envFallback =
    cmd: a:
    optionalString (a.env != null) ''
      if ${notGiven a} && ${envSet a}; then
        ${
          if a.kind == "flag" then
            ''
              ${flagFromEnv cmd a}
              ${names.given a.key}=1''
          else
            "${names.setter a.key} ${envValue a} ${envShown a} ${cmd}"
        }
      fi'';

  defaultAssignment =
    a:
    if a.kind == "flag" then
      optionalString (a.default == true) "${names.value a.key}=1"
    else if argument.isList a then
      "${names.list a.key}=(${concatMapStringsSep " " q (lib.toList a.default)})"
    else
      "${names.value a.key}=${q a.default}";

  defaultValue =
    a:
    let
      assignment = defaultAssignment a;
    in
    optionalString (a.default != null && assignment != "") "if ${notGiven a}; then ${assignment}; fi";

  requiredCheck =
    cmd: a:
    optionalString a.required ''${names.isGiven a} || __scripter_args_error "missing required option '--${a.long}'" ${cmd}'';

  constraintChecks =
    cmd: level: c:
    let
      byName =
        n: lib.findFirst (a: a.name == n) (throw "unknown argument ${n}") (levels.allArguments level);
      countGiven =
        ns: "__scripter_args_count_given ${concatMapStringsSep " " (n: names.givenRef (byName n)) ns}";
      shownList = ns: concatMapStringsSep ", " (n: "'${names.shown (byName n)}'") ns;
      exclusive = ns: ''
        ${countGiven ns}
        [ "$__scripter_args_n" -le 1 ] || __scripter_args_error "only one of ${shownList ns} may be given" ${cmd}'';
      oneOf = ns: ''
        ${countGiven ns}
        [ "$__scripter_args_n" -eq 1 ] || __scripter_args_error "exactly one of ${shownList ns} must be given" ${cmd}'';
      requires =
        n: dep:
        let
          a = byName n;
          d = byName dep;
        in
        ''
          if ${names.isGiven a} && ! ${names.isGiven d}; then
            __scripter_args_error "'${names.shown a}' requires '${names.shown d}'" ${cmd}
          fi'';
    in
    lib.concatStringsSep "\n" (
      lib.optional (c.exclusive != null) (exclusive c.exclusive)
      ++ lib.optional (c.oneOf != null) (oneOf c.oneOf)
      ++ lib.optionals (c.requires != null) (
        lib.concatLists (lib.mapAttrsToList (n: deps: map (requires n) deps) c.requires)
      )
    );

  globalAction =
    a:
    optionalString (argument.isGlobal a) "__scripter_args_apply_global ${a.action} ${names.valueRef a}";

  lines = f: xs: lib.concatStringsSep "\n" (lib.filter (s: s != "") (map f xs));
in
{
  finishFunction =
    level:
    let
      cmd = q level.display;
      own = levels.ownArguments level;
    in
    ''
      ${names.finish level}() {
        :
        ${lines (envFallback cmd) own}
        ${lines defaultValue own}
        ${lines (requiredCheck cmd) own}
        ${lines (constraintChecks cmd level) level.constraints}
        ${lines globalAction own}
      }'';
}
