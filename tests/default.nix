{ pkgs, scripterLib }:
let
  inherit (pkgs) lib;
  args = {
    inherit pkgs lib;
    scripter = scripterLib.mkScripter { inherit pkgs; };
  }
  // import ./helpers.nix { inherit pkgs; };
in
lib.mergeAttrsList (
  map (suite: import suite args) [
    ./minimal.nix
    ./ui.nix
    ./args.nix
    ./standalone.nix
    ./errors.nix
    ./generate.nix
    ./discover.nix
    ./evaluation.nix
  ]
)
