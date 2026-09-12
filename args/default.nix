# Pure parts of the argument parser generator.
{ lib }:
{
  types = import ./types.nix { inherit lib; };
  inherit (import ./ir.nix { inherit lib; }) ir irVersion;
  help = import ./help.nix { inherit lib; };
  completions = import ./completions.nix { inherit lib; };
}
