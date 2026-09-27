# Every value is a default, so scripts can override anything a preset sets.
{ lib }:
let
  d = lib.mkDefault;
in
{
  recommended = {
    features = {
      core.enable = d true;
      ctx.enable = d true;
      ui = {
        enable = d true;
        icons = d "unicode";
      };
    };
    args.globals = {
      verbose = d true;
      quiet = d true;
      color = d true;
      yes = d true;
    };
  };

  hermetic = {
    path = d "replace";
  };

  portable = {
    mode = d "standalone";
    bash.target = d "3.2";
  };

  strict = {
    check.shellcheck.severity = d "style";
    check.shfmt.enable = d true;
  };
}
