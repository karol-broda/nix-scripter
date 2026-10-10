{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  naming = import ../../../args/ir/naming.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };
  inherit (import ../../../lib/util.nix { inherit lib; }) joinLines shellQuote;

  chunksOf = n: xs: if xs == [ ] then [ ] else [ (lib.take n xs) ] ++ chunksOf n (lib.drop n xs);

  initial =
    a:
    if argument.isList a then
      "${names.list a.key}=()"
    else
      "${names.value a.key}=${if a.kind == "flag" && a.count then "0" else "\"\""}";

  exportLine =
    vars: a:
    if argument.isList a then
      "${naming.listVariable vars a}=(${names.listRef a})"
    else if vars.style == "assoc" then
      "${vars.name}[${a.key}]=${names.valueRef a}"
    else
      "${naming.globalVariable vars a}=${names.valueRef a}";

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
      "__scripter_json_flag ${names.valueRef a}"
    else if a.kind == "flag" then
      "__scripter_json num ${names.valueRef a}"
    else
      "__scripter_json ${kind} ${names.valueRef a}";

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
      map (chunk: lib.concatStringsSep " " chunk) (chunksOf 4 (map initial arguments))
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
      ${joinLines (map (exportLine vars) arguments)}
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
