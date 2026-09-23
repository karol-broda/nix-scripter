# Runs `args.tests`: each case executes the generated parser in isolation
# (no user code) and compares the parsed values with the expectation.
{
  lib,
  pkgs,
  name,
  ir,
  argsCode,
  backend,
  config,
}:
let
  q = lib.escapeShellArg;

  harness = pkgs.writeTextFile {
    name = "${name}-args-harness";
    executable = true;
    text = ''
      #!${backend.checkInterpreter pkgs}
      set -euo pipefail
      __scripter_name='${name}'
      __scripter_version='${config.version}'

      ${argsCode.parser}
      __scripter_args_parse_root "$@"
      ${argsCode.dump}
    '';
  };

  runCase =
    i: t:
    let
      label = "case ${toString i} (${lib.concatStringsSep " " (map q t.argv)})";
      envArgs = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${q v}") t.env);
    in
    ''
      echo "--- ${label}"
      rc=0
      env -i PATH="$PATH" HOME="$TMPDIR" ${envArgs} ${harness} ${lib.escapeShellArgs t.argv} \
        > stdout.txt 2> stderr.txt || rc=$?
      if [ "$rc" -ne ${toString t.exitCode} ]; then
        echo "FAIL ${label}: exit code $rc, expected ${toString t.exitCode}" >&2
        cat stderr.txt >&2
        failed=1
      fi
      ${lib.optionalString (t.stderrContains != null) ''
        if ! grep -qF -- ${q t.stderrContains} stderr.txt; then
          echo "FAIL ${label}: stderr does not contain ${q t.stderrContains}" >&2
          cat stderr.txt >&2
          failed=1
        fi
      ''}
      ${lib.optionalString (t.stdoutContains != null) ''
        if ! grep -qF -- ${q t.stdoutContains} stdout.txt; then
          echo "FAIL ${label}: stdout does not contain ${q t.stdoutContains}" >&2
          cat stdout.txt >&2
          failed=1
        fi
      ''}
      ${lib.optionalString (t.expect != { } && t.exitCode == 0) ''
        if ! jq -e --argjson exp ${q (builtins.toJSON t.expect)} \
          '. as $act | $exp | to_entries | all(.value == $act[.key])' stdout.txt > /dev/null; then
          echo "FAIL ${label}: parsed values differ" >&2
          echo "  expected (subset): ${lib.replaceStrings [ "$" ] [ "\\$" ] (builtins.toJSON t.expect)}" >&2
          echo "  actual:            $(cat stdout.txt)" >&2
          failed=1
        fi
      ''}
    '';
in
pkgs.runCommandLocal "${name}-args-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  failed=0
  ${lib.concatStringsSep "\n" (lib.imap1 runCase ir.tests)}
  if [ "$failed" -ne 0 ]; then
    exit 1
  fi
  touch $out
''
