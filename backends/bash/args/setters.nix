{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };

  allowedValues =
    a: lib.optionalString (a.values != null) " ${lib.concatMapStringsSep " " q a.values}";
  pattern = a: q (if a.pattern != null then a.pattern else "");

  store = a: if argument.isList a then "${names.list a.key}+=(\"$1\")" else "${names.value a.key}=$1";
in
{
  # Called as: setter <value> <name shown in errors> <command path>
  setterFunction = a: ''
    ${names.setter a.key}() {
      __scripter_args_check ${q a.type} "$1" "$2" "$3" ${pattern a}${allowedValues a}
      ${store a}
      ${names.given a.key}=1
    }'';
}
