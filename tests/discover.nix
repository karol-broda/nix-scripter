{
  pkgs,
  lib,
  scripter,
  runTest,
  ...
}:
let
  discovered = scripter.discover { dir = ./fixtures/scripts; };
  discoveredPkgs = lib.mapAttrs (_: scripter.mkScript) discovered;
in
{
  discover = runTest "discover" [ ] ''
    ${discoveredPkgs.greet}/bin/greet > greet.txt
    expect_contains greet.txt "hello from discovered"
    ${discoveredPkgs.tool}/bin/tool > tool.txt
    expect_contains tool.txt "tool main"
    ${lib.optionalString (discovered ? _ignored) "fail '_ignored was discovered'"}
  '';
}
