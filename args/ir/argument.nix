{ lib }:
let
  naming = import ./naming.nix { inherit lib; };

  # Every IR argument carries every field, so generators never need `or`.
  blank = {
    short = null;
    long = null;
    env = null;
    var = null;
    hidden = false;
    description = "";
    negatable = false;
    count = false;
    type = null;
    values = null;
    pattern = null;
    default = null;
    complete = null;
    required = false;
    repeated = false;
    optional = false;
    variadic = false;
    metavar = null;
    action = null;
  };

  defaultToString =
    v:
    if v == null then
      null
    else if lib.isString v then
      v
    else if lib.isBool v then
      (if v then "1" else "")
    else if lib.isList v then
      map defaultToString v
    else
      builtins.toJSON v;

  keyOf = name: spec: naming.sanitize (if spec.var != null then spec.var else name);

  resolveNegatable = negatableDefault: n: if n == null then negatableDefault else n;

  mkArgument = fields: blank // fields;

  flag =
    negatableDefault: name: spec:
    mkArgument {
      kind = "flag";
      inherit name;
      key = keyOf name spec;
      inherit (spec)
        short
        long
        env
        var
        hidden
        count
        description
        ;
      negatable = resolveNegatable negatableDefault spec.negatable;
    };

  boolOption =
    negatableDefault: name: spec:
    mkArgument {
      kind = "flag";
      inherit name;
      key = keyOf name spec;
      inherit (spec)
        short
        long
        env
        var
        hidden
        description
        ;
      negatable = resolveNegatable negatableDefault spec.negatable;
      default = if spec.default == null then null else spec.default == true;
    };

  valuedOption =
    name: spec:
    mkArgument {
      kind = "option";
      inherit name;
      key = keyOf name spec;
      inherit (spec)
        short
        long
        type
        values
        pattern
        env
        var
        hidden
        required
        repeated
        complete
        description
        ;
      metavar = if spec.metavar != null then spec.metavar else lib.toUpper (naming.sanitize name);
      default = defaultToString spec.default;
    };

  option =
    negatableDefault: name: spec:
    if spec.type == "bool" then boolOption negatableDefault name spec else valuedOption name spec;

  positional =
    spec:
    mkArgument {
      kind = "positional";
      inherit (spec)
        name
        type
        values
        pattern
        env
        var
        optional
        variadic
        complete
        description
        hidden
        ;
      key = keyOf spec.name spec;
      default = defaultToString spec.default;
      metavar = spec.name;
    };

  isList = a: a.repeated || a.variadic;
  isNumeric =
    a:
    lib.elem a.type [
      "int"
      "float"
    ];
  isFileLike =
    a:
    lib.elem a.type [
      "path"
      "file"
    ];
  isDir = a: a.type == "dir";
  takesValue = a: a.kind == "option";
  isGlobal = a: a.action != null;
in
{
  inherit
    mkArgument
    flag
    option
    positional
    isList
    isNumeric
    isFileLike
    isDir
    takesValue
    isGlobal
    ;
}
