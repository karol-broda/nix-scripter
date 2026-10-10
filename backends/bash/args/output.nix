{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  naming = import ../../../args/ir/naming.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };
  inherit (import ../../../lib/util.nix { inherit lib; }) joinLines shellQuote;

  lists = lib.filter argument.isList;
  scalars = lib.filter (a: !argument.isList a);
  counters = lib.filter (a: a.kind == "flag" && a.count);

  valueOrEmpty = a: "\"\${${names.value a.key}:-}\"";

  listExport = vars: a: "${naming.listVariable vars a}=(${names.listRef a})";

  scalarExports =
    vars: arguments:
    if vars.style == "assoc" then
      [
        ''
          local __scripter_key __scripter_value
          for __scripter_key in ${lib.concatMapStringsSep " " (a: a.key) arguments}; do
            __scripter_value="__scripter_av_$__scripter_key"
            ${vars.name}[$__scripter_key]=''${!__scripter_value:-}
          done''
      ]
    else
      map (a: "${naming.globalVariable vars a}=${valueOrEmpty a}") arguments;

  commandExport =
    vars:
    if vars.style == "assoc" then
      "${vars.name}[${vars.command}]=\"$__scripter_args_command\""
    else
      "${naming.commandVariable vars}=\"$__scripter_args_command\"";

  dumpValue =
    a:
    let
      kind = if argument.isNumeric a then "num" else "str";
    in
    if argument.isList a then
      "__scripter_json_list ${kind} ${names.listRef a}"
    else if a.kind == "flag" && !a.count then
      "__scripter_json_flag ${valueOrEmpty a}"
    else if a.kind == "flag" then
      "__scripter_json num ${valueOrEmpty a}"
    else
      "__scripter_json ${kind} ${valueOrEmpty a}";

  dumpEntry = a: ''
    printf '%s:' ${q (builtins.toJSON a.key)}
    ${dumpValue a}
    printf ','
  '';
in
{
  variables =
    ir: arguments:
    joinLines (
      map (a: "${names.list a.key}=()") (lists arguments)
      ++ map (a: "${names.value a.key}=0") (counters arguments)
      ++ [
        "__scripter_args_command=\"\" __scripter_args_cmd=${shellQuote ir.name}"
        "__scripter_args_help_enabled=${if ir.globals.help then "1" else "\"\""}"
        "__scripter_args_version_enabled=${if ir.globals.version then "1" else "\"\""}"
      ]
      ++ lib.optional (ir.vars.style == "assoc") "declare -A ${ir.vars.name}=()"
    );

  exportFunction = vars: arguments: ''
    # shellcheck disable=SC2034
    __scripter_args_export() {
      ${joinLines (scalarExports vars (scalars arguments) ++ map (listExport vars) (lists arguments))}
      ${commandExport vars}
    }'';

  dump = arguments: ''
    ${builtins.readFile ./json.bash}
    printf '{'
    ${lib.concatMapStrings dumpEntry arguments}
    printf '"_command":'
    __scripter_json str "$__scripter_args_command"
    printf '}\n'
  '';
}
