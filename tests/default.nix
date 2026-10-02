{ pkgs, scripterLib }:
let
  inherit (pkgs) lib;
  args = {
    inherit pkgs lib;
    scripter = scripterLib.mkScripter { inherit pkgs; };
    bash_3_2 = pkgs.callPackage ./packages/bash_3_2.nix { };
  }
  // import ./helpers.nix { inherit pkgs; };
in
lib.mergeAttrsList (
  map (suite: import suite args) [
    ./minimal.nix
    ./ui.nix
    ./args.nix
    ./standalone.nix
    ./compat.nix
    ./errors.nix
    ./generate.nix
    ./discover.nix
    ./evaluation.nix
  ]
)
