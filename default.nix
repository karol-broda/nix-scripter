# Entry point without flakes:
#
#   scripter = import nix-scripter { inherit pkgs; };
{
  pkgs ? import <nixpkgs> { },
  modules ? [ ],
  extensions ? [ ],
}:
(import ./lib { inherit (pkgs) lib; }).mkScripter { inherit pkgs modules extensions; }
