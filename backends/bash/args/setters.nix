{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };

  needsCheck =
    a:
    a.pattern != null
    || lib.elem a.type [
      "int"
      "float"
      "file"
      "dir"
      "enum"
    ];

  check =
    a:
    "__scripter_args_check ${a.type} \"$1\" \"$2\" ${q (if a.pattern != null then a.pattern else "")}"
    + lib.optionalString (a.values != null) " ${lib.escapeShellArgs a.values}"
    + "; ";

  store =
    a:
    if argument.isList a then
      "${names.list a.key}+=(\"$1\"); ${names.given a.key}=1;"
    else
      "${names.value a.key}=$1 ${names.given a.key}=1;";
in
{
  # Called as: setter <value> <name shown in errors>
  setterFunction =
    level: a: "${names.setter level a}() { ${lib.optionalString (needsCheck a) (check a)}${store a} }";
}
