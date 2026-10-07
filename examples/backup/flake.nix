{
  description = "A restic backup tool built with nix-scripter";

  inputs = {
    scripter.url = "path:../..";
    nixpkgs.follows = "scripter/nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, scripter, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ scripter.flakeModules.default ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      scripter.defaults = scripter.lib.presets.recommended;

      perSystem =
        { config, pkgs, ... }:
        {
          scripter.scripts.backup = ./backup.nix;
          scripter.expose.default = "backup";

          checks.roundtrip = pkgs.callPackage ./roundtrip.nix { backup = config.scripter.packages.backup; };
        };
    };
}
