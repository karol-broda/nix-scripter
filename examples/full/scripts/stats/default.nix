{ pkgs, ... }:
{
  description = "Directory script: default.nix plus main.bash";
  deps = [ pkgs.coreutils ];
}
