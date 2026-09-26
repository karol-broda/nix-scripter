{ lib }:
{
  types = import ./types { inherit lib; };
  ir = import ./ir { inherit lib; };
  help = import ./help.nix { inherit lib; };
  completions = import ./completions { inherit lib; };
}
