{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  argument = import ../../../args/ir/argument.nix { inherit lib; };

  shape = a: if argument.isList a then "list" else "scalar";
  pattern = a: q (if a.pattern != null then a.pattern else "");
  allowedValues = a: lib.optionalString (a.values != null) " ${lib.escapeShellArgs a.values}";
in
{
  setterFunction =
    level: a:
    "${names.setter level a}() { __scripter_args_store ${a.key} ${shape a} ${a.type} ${pattern a} \"$1\" \"$2\"${allowedValues a}; }";
}
