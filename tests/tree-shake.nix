{
  pkgs,
  lib,
  scripter,
  runTest,
  ...
}:
let
  shaken =
    module:
    scripter.bash {
      imports = [
        module
        scripter.presets.small
      ];
    };

  ui = {
    name = "ui-demo";
    features.ui = true;
    src = ./fixtures/ui-demo.bash;
  };

  dynamicCall = {
    name = "dynamic";
    features.ui = true;
    text = ''
      level=warn
      "ui::$level" "computed call"
    '';
  };

  full = scripter.bash ui;
  small = shaken ui;
  withoutKeep = shaken dynamicCall;
  withKeep = shaken (dynamicCall // { passes.treeShake.keep = [ "ui::warn" ]; });
  commands = shaken ./scripts/commands.nix;
  argsDemo = shaken ./scripts/args-demo.nix;
  errors = shaken {
    name = "fails";
    features.core = true;
    src = ./fixtures/fails.sh;
  };

  withoutTimings = "sed -E 's/\\([0-9.]+m?s\\)//'";
in
{
  tree-shake-args = argsDemo.checks.args;
  tree-shake-commands = commands.checks.args;

  tree-shake = runTest "tree-shake" [ pkgs.util-linux ] ''
    [ "$(wc -l < ${small}/bin/ui-demo)" -lt "$(wc -l < ${full}/bin/ui-demo)" ] || fail "nothing was removed"
    ! grep -q '^ui::choose()' ${small}/bin/ui-demo || fail "unused ui::choose was kept"
    grep -q '^ui::spin()' ${small}/bin/ui-demo || fail "used ui::spin was removed"

    for env in "" "GITHUB_ACTIONS=true" "GITLAB_CI=true" "TF_BUILD=True" "TEAMCITY_VERSION=1"; do
      env $env ${full}/bin/ui-demo > full.out 2> full.err
      env $env ${small}/bin/ui-demo > small.out 2> small.err
      diff full.out small.out || fail "stdout differs ($env)"
      diff <(${withoutTimings} full.err | grep -v section_) <(${withoutTimings} small.err | grep -v section_) ||
        fail "ui output differs ($env)"
    done
    script -qec ${small}/bin/ui-demo /dev/null > tty.txt
    expect_contains tty.txt "an info"

    rc=0
    ${errors}/bin/fails 2> err.txt || rc=$?
    [ "$rc" -eq 1 ] || fail "expected exit 1, got $rc"
    expect_contains err.txt "at inner (fails.sh:3)"
    expect_contains err.txt "cleanup ran"

    res=$(${commands}/bin/cmds db migrate 2)
    [ "$res" = "$(printf 'setup runs first\nmigrating 2 steps')" ] || fail "commands: $res"

    rc=0
    ${withoutKeep}/bin/dynamic 2> nokeep.txt || rc=$?
    [ "$rc" -ne 0 ] || fail "computed call without keep should fail"
    ${withKeep}/bin/dynamic 2> keep.txt
    expect_contains keep.txt "computed call"
  '';
}
