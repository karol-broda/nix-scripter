{
  pkgs,
  lib,
  scripter,
  runTest,
  ...
}:
let
in
{
  minimal = runTest "minimal" [ ] ''
    res=$(${
      scripter.bash {
        name = "hello";
        deps = [ pkgs.hello ];
        text = ''hello -g "hi $1"'';
      }
    }/bin/hello there)
    [ "$res" = "hi there" ] || fail "unexpected output: $res"
  '';
}
