{ lib }:
{
  bash = import ./bash.nix { inherit lib; };
  zsh = import ./zsh.nix { inherit lib; };
  fish = import ./fish.nix { inherit lib; };
}
