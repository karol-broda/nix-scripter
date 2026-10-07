{
  description = "Consistent, composable scripts built with Nix";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      scripterLib = import ./lib { inherit lib; };
    in
    {
      lib = scripterLib;

      overlays.default = final: _prev: {
        scripter = scripterLib.mkScripter { pkgs = final; };
      };

      flakeModules.default = import ./flake-module { inherit scripterLib; };

      legacyPackages = forAllSystems (pkgs: {
        scripter = scripterLib.mkScripter { inherit pkgs; };
      });

      checks = forAllSystems (pkgs: import ./tests { inherit pkgs scripterLib; });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            bashInteractive
            jq
            nixfmt
            shellcheck
            shfmt
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
