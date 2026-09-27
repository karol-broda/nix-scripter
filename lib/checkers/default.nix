# A checker's `command` is a shell snippet that may use
#   $source       the assembled script
#   $userSource   the user's own main source
#   $diagnostics  a file to write a JSON array of { line; column; level; code; message; } to
# Diagnostics are mapped back to the user's files through the source map.
# Checkers with `output = "raw"` report on their own and exit non-zero.
{ lib }:
{
  syntax = import ./syntax.nix { inherit lib; };
  shellcheck = import ./shellcheck.nix { inherit lib; };
  shfmt = import ./shfmt.nix { inherit lib; };
}
