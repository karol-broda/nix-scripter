# Presets hold the opinions. They are ordinary modules; every value is a
# default, so a script can still override anything a preset sets.
{ lib }:
let
  d = lib.mkDefault;
in
{
  # Library + common global flags + unicode icons.
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

  # Only Nix-provided commands are on PATH.
  hermetic = {
    path = d "replace";
  };

  # A single file that runs on any host with bash ≥ 3.2 (macOS included).
  portable = {
    mode = d "standalone";
    bash.target = d "3.2";
  };

  # Stricter static checks.
  strict = {
    check.shellcheck.severity = d "style";
    check.shfmt.enable = d true;
  };
}
