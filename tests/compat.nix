{
  pkgs,
  lib,
  scripter,
  runTest,
  bash_3_2,
  ...
}:
let
  bash32 = "${bash_3_2}/bin/bash";

  onBash32 = {
    mode = "standalone";
    bash.target = "3.2";
    bash.testPackage = bash_3_2;
  };

  uiScript = scripter.bash {
    imports = [ onBash32 ];
    name = "ui-demo";
    features.ui = true;
    src = ./fixtures/ui-demo.bash;
  };

  argsScript = scripter.bash {
    imports = [
      ./scripts/args-demo.nix
      onBash32
    ];
    text = lib.mkForce ''
      printf 'env=%s timeout=%s tags=%s\n' "$ARG_ENV" "$ARG_TIMEOUT" "''${args_tag[*]-}"
    '';
  };

  commandsScript = scripter.bash {
    imports = [
      ./scripts/commands.nix
      onBash32
    ];
    args.commands.status.text = lib.mkForce ''
      echo "status json=$ARG_JSON dry=$ARG_DRY cmd=$ARG__COMMAND"
    '';
    text = lib.mkForce ''
      echo "setup runs first"
      cmd::db::migrate() {
        echo "migrating $ARG_STEPS steps"
      }
    '';
  };

  errorScript = scripter.bash {
    imports = [ onBash32 ];
    name = "fails";
    features.core = true;
    src = ./fixtures/fails.sh;
  };

  needs44 = scripter.bash {
    name = "needs44";
    mode = "standalone";
    bash.target = "4.4";
    text = "echo unreachable";
  };

  withoutTimings = "sed -E 's/\\([0-9.]+m?s\\)//'";
in
{
  compat-args = argsScript.checks.args;
  compat-commands = commandsScript.checks.args;

  compat-ui = runTest "compat-ui" [ pkgs.bash ] ''
    for env in "" "GITHUB_ACTIONS=true" "GITLAB_CI=true" "SCRIPTER_ICONS=unicode SCRIPTER_UI=fancy"; do
      env $env ${bash32} ${uiScript}/bin/ui-demo > out32.txt 2> err32.txt
      env $env bash ${uiScript}/bin/ui-demo > out5.txt 2> err5.txt
      diff out5.txt out32.txt || fail "stdout differs on bash 3.2 ($env)"
      diff <(${withoutTimings} err5.txt | grep -v section_) <(${withoutTimings} err32.txt | grep -v section_) ||
        fail "ui output differs on bash 3.2 ($env)"
    done
  '';

  compat-run = runTest "compat-run" [ ] ''
    res=$(${bash32} ${argsScript}/bin/args-demo prod --tag a --tag b)
    [ "$res" = "env=prod timeout=30 tags=a b" ] || fail "args: $res"
    res=$(${bash32} ${commandsScript}/bin/cmds st --json)
    [ "$res" = "$(printf 'setup runs first\nstatus json=1 dry= cmd=status')" ] || fail "status: $res"
    res=$(${bash32} ${commandsScript}/bin/cmds db migrate 2)
    [ "$res" = "$(printf 'setup runs first\nmigrating 2 steps')" ] || fail "migrate: $res"
    ! grep -q 'declare -A' ${argsScript}/bin/args-demo || fail "3.2 target declared an associative array"
  '';

  compat-errors = runTest "compat-errors" [ ] ''
    rc=0
    ${bash32} ${errorScript}/bin/fails 2> err.txt || rc=$?
    [ "$rc" -eq 1 ] || fail "expected exit 1, got $rc"
    expect_contains err.txt "at inner (fails.sh:1, function start)"
    expect_contains err.txt "at outer (fails.sh:7)"
    expect_contains err.txt "at main (fails.sh:10)"
    expect_contains err.txt "cleanup ran"
  '';

  compat-version-guard = runTest "compat-version-guard" [ ] ''
    rc=0
    ${bash32} ${needs44}/bin/needs44 2> err.txt || rc=$?
    [ "$rc" -eq 1 ] || fail "expected exit 1, got $rc"
    expect_contains err.txt "needs44: error: bash >= 4.4 is required, this is 3.2.57(1)-release"
    expect_not_contains err.txt unreachable
  '';
}
