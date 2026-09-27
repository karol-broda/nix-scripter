{
  lib,
  config,
  context,
}:
let
  argsIR = import ../../args/ir { inherit lib; };
  inherit (context) backend target caps;

  style = if config.args.vars.style != null then config.args.vars.style else backend.argsStyle target;

  built = argsIR.build {
    inherit (config) name version description;
    inherit style;
    spec = config.args;
  };

  styleUnsupported = style == "assoc" && !lib.elem "assoc-arrays" caps;
in
{
  inherit (config.args) enable;
  inherit (built) ir;
  code = backend.argsCodegen { inherit (built) ir; };

  errors = lib.optionals config.args.enable (
    built.errors
    ++ lib.optional styleUnsupported "args.vars.style = \"assoc\" needs assoc-arrays, which ${config.lang} target ${target} does not have"
  );
}
