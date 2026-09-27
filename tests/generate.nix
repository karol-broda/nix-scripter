{
  pkgs,
  lib,
  scripter,
  runTest,
  ...
}:
let
  generated = scripter.args.generate {
    name = "handwritten";
    spec = ./fixtures/args.toml;
  };
in
{
  generate = runTest "generate" [ ] ''
    cat > handwritten.sh <<'EOF'
    set -euo pipefail
    source ${generated}/parser.bash
    args_parse "$@"
    echo "greeting=''${args[greeting]} loud=''${args[loud]}"
    EOF
    res=$(bash handwritten.sh --loud)
    [ "$res" = "greeting=hello loud=1" ] || fail "unexpected: $res"
    expect_contains ${generated}/help.txt "Usage: handwritten [OPTIONS]"
    test -f ${generated}/completions/_handwritten
  '';
}
