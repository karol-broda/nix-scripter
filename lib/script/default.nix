{ registry }:
{
  imports = [
    ./options.nix
    (import ./features.nix { inherit registry; })
    (import ./checks.nix { inherit registry; })
    (import ./backends.nix { inherit registry; })
    ./args.nix
    ./passes.nix
  ];
}
