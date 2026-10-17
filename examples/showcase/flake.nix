{
  description = "A tour of the terminal output nix-scripter produces";

  inputs = {
    scripter.url = "path:../..";
    nixpkgs.follows = "scripter/nixpkgs";
  };

  outputs =
    { nixpkgs, scripter, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          f pkgs (scripter.lib.mkScripter { inherit pkgs; })
        );

      showcase =
        s:
        s.bash {
          imports = with s.presets; [
            recommended
            small
          ];
          name = "showcase";
          description = "Show off what the ui feature renders";
          src = ./showcase.sh;
          args.options = {
            as = {
              values = [
                "auto"
                "terminal"
                "plain"
                "github"
                "gitlab"
              ];
              default = "auto";
              description = "Render as if running in this environment";
            };
            icons = {
              values = [
                "ascii"
                "unicode"
                "nerdfont"
              ];
              description = "Icon set (default: unicode)";
            };
            delay = {
              type = "float";
              default = "0.05";
              description = "Seconds between progress steps";
            };
          };
        };
    in
    {
      packages = forAllSystems (_: s: { default = showcase s; });

      checks = forAllSystems (
        pkgs: s:
        let
          script = showcase s;
        in
        {
          renders = pkgs.runCommand "showcase-renders" { } ''
            for as in plain github gitlab; do
              ${script}/bin/showcase --as "$as" --delay 0 > /dev/null 2> "$as.txt"
            done
            grep -q '^\[ok\] success: it worked' plain.txt
            grep -q '^::group::Groups (collapsible in CI logs)' github.txt
            grep -q '^::warning file=showcase.sh,line=42::' github.txt
            grep -q '^::add-mask::hunter2' github.txt
            grep -q 'section_start:' gitlab.txt
            touch $out
          '';
        }
      );
    };
}
