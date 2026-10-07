{ lib }:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    filter
    optional
    optionalString
    ;
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  levels = import ../../../args/ir/levels.nix { inherit lib; };

  spellings =
    a: concatStringsSep " | " ([ "--${a.long}" ] ++ optional (a.short != null) "-${a.short}");

  setFlag =
    a:
    if a.count then
      "${names.value a.key}=$((${names.value a.key} + 1)); ${names.given a.key}=1"
    else
      "${names.value a.key}=1; ${names.given a.key}=1";

  flagBranches = cmd: a: {
    exact = ''
      ${spellings a})
        ${setFlag a}
        ;;
      --${a.long}=*)
        __scripter_args_error "option '--${a.long}' does not take a value" ${cmd}
        ;;''
    + optionalString a.negatable ''

      --no-${a.long})
        ${names.value a.key}=${if a.count then "0" else "\"\""}; ${names.given a.key}=1
        ;;'';
    bundled = optionalString (a.short != null) ''
      -${a.short}?*)
        ${setFlag a}
        shift
        set -- "-''${__scripter_arg#-${a.short}}" "$@"
        continue
        ;;'';
  };

  optionBranches = cmd: a: {
    exact = ''
      ${spellings a})
        __scripter_args_require_value "$#" "$__scripter_arg" ${cmd}
        ${names.setter a.key} "$2" "$__scripter_arg" ${cmd}
        shift
        ;;
      --${a.long}=*)
        ${names.setter a.key} "''${__scripter_arg#*=}" '--${a.long}' ${cmd}
        ;;'';
    bundled = optionalString (a.short != null) ''
      -${a.short}?*)
        ${names.setter a.key} "''${__scripter_arg#-${a.short}}" '-${a.short}' ${cmd}
        ;;'';
  };

  branchesFor = cmd: a: if a.kind == "flag" then flagBranches cmd a else optionBranches cmd a;

  knownLongs =
    ir: level:
    let
      accepted = levels.acceptedOptions level;
    in
    map (a: "--${a.long}") accepted
    ++ map (a: "--no-${a.long}") (filter (a: a.kind == "flag" && a.negatable) accepted)
    ++ optional ir.globals.help "--help"
    ++ optional (ir.globals.version && level.isRoot) "--version";

  helpBranches = level: ''
    -h | --help | -h?*)
      ${names.help level}
      exit 0
      ;;'';

  versionBranch = ''
    --version)
      printf '%s %s\n' "$__scripter_name" "$__scripter_version"
      exit 0
      ;;'';

  subcommandBranch = level: sub: ''
    ${concatMapStringsSep " | " q (levels.commandNames sub)})
      __scripter_args_command=${q (concatStringsSep " " sub.path)}
      shift
      ${names.parse sub} "$@"
      ${names.finish level}
      return 0
      ;;'';

  wordBranch =
    cmd: level:
    if level.commands == [ ] then
      ''__scripter_pos+=("$__scripter_arg")''
    else
      ''
        case $__scripter_arg in
        ${concatMapStringsSep "\n" (subcommandBranch level) level.commands}
          *)
            __scripter_args_suggest "$__scripter_arg" ${
              concatMapStringsSep " " q (lib.concatMap levels.commandNames level.commands)
            }
            __scripter_args_error "unrecognized command '$__scripter_arg'" ${cmd} "''${__scripter_args_hint:-}"
            ;;
        esac'';

  positionalCount = ''"''${#__scripter_pos[@]}"'';

  requiredPositionalsCheck =
    cmd: level:
    let
      required = filter (p: !p.optional && !p.variadic) level.positional;
      count = lib.length required;
    in
    optionalString (count > 0) ''
      if [ ${positionalCount} -lt ${toString count} ]; then
        __scripter_args_error "missing required argument${optionalString (count > 1) "s"} ${
          concatMapStringsSep " " names.shown required
        }" ${cmd}
      fi'';

  assignFixed = cmd: i: p: ''
    if [ ${positionalCount} -gt ${toString i} ]; then
      ${names.setter p.key} "''${__scripter_pos[${toString i}]}" '${names.shown p}' ${cmd}
    fi'';

  assignRest =
    cmd: fixedCount: variadic:
    let
      n = toString fixedCount;
    in
    if variadic != null then
      ''
        if [ ${positionalCount} -gt ${n} ]; then
          for __scripter_arg in "''${__scripter_pos[@]:${n}}"; do
            ${names.setter variadic.key} "$__scripter_arg" '${names.shown variadic}' ${cmd}
          done
        fi''
    else
      ''
        if [ ${positionalCount} -gt ${n} ]; then
          __scripter_arg=''${__scripter_pos[${n}]}
          __scripter_args_error "unexpected argument '$__scripter_arg'" ${cmd}
        fi'';

  assignPositionals =
    cmd: level:
    let
      fixed = filter (p: !p.variadic) level.positional;
      variadic = lib.findFirst (p: p.variadic) null level.positional;
    in
    lib.concatStringsSep "\n" (
      [ (requiredPositionalsCheck cmd level) ]
      ++ lib.imap0 (assignFixed cmd) fixed
      ++ [ (assignRest cmd (lib.length fixed) variadic) ]
    );

  afterLoop =
    cmd: level:
    if level.commands != [ ] then
      ''__scripter_args_error "missing command (one of: ${
        concatStringsSep ", " (map (c: c.name) level.commands)
      })" ${cmd}''
    else
      ''
        ${assignPositionals cmd level}
        ${names.finish level}'';
in
{
  parseFunction =
    ir: level:
    let
      cmd = q level.display;
      branches = map (branchesFor cmd) (levels.acceptedOptions level);
    in
    ''
      ${names.parse level}() {
        local __scripter_arg
        local -a __scripter_pos=()
        while [ "$#" -gt 0 ]; do
          __scripter_arg=$1
          case $__scripter_arg in
            --)
              shift
              while [ "$#" -gt 0 ]; do
                __scripter_pos+=("$1")
                shift
              done
              break
              ;;
      ${optionalString (ir.globals.version && level.isRoot) versionBranch}
      ${concatMapStringsSep "\n" (b: b.exact) branches}
      ${concatMapStringsSep "\n" (b: b.bundled) branches}
      ${optionalString ir.globals.help (helpBranches level)}
            --*)
              __scripter_args_suggest "''${__scripter_arg%%=*}" ${
                concatMapStringsSep " " q (knownLongs ir level)
              }
              __scripter_args_error "unrecognized option '$__scripter_arg'" ${cmd} "''${__scripter_args_hint:-}"
              ;;
            -?*)
              __scripter_args_error "unrecognized option '$__scripter_arg'" ${cmd}
              ;;
            *)
              ${wordBranch cmd level}
              ;;
          esac
          shift
        done
        ${afterLoop cmd level}
      }'';

  helpFunction = text: level: ''
    # shellcheck disable=SC2016
    ${names.help level}() {
      printf '%s\n' ${q text}
    }'';

}
