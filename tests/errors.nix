{
  pkgs,
  lib,
  scripter,
  runTest,
  ...
}:
let
  errorScript = scripter.bash {
    name = "fails";
    features.core = true;
    src = ./fixtures/fails.sh;
  };
in
{
  errors = runTest "errors" [ ] ''
    rc=0
    ${errorScript}/bin/fails 2> err.txt || rc=$?
    [ "$rc" -eq 3 ] || fail "expected exit 3, got $rc"
    expect_contains err.txt "fails: error: command failed with exit code 3"
    expect_contains err.txt "at inner (fails.sh:3)"
    expect_contains err.txt "at outer (fails.sh:7)"
    expect_contains err.txt "at main (fails.sh:10)"
    expect_contains err.txt "cleanup ran"
  '';
}
