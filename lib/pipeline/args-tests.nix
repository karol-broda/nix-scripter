{
  lib,
  pkgs,
  config,
  name,
  backend,
  ir,
  code,
}:
let
  q = lib.escapeShellArg;
  util = import ../util.nix { inherit lib; };

  harness = pkgs.writeTextFile {
    name = "${name}-args-harness";
    executable = true;
    text = ''
      #!${backend.checkInterpreter pkgs}
      set -euo pipefail
      __scripter_name=${util.shellQuote name}
      __scripter_version=${util.shellQuote config.version}
      ${code.parser}
      __scripter_args_parse_root "$@"
      ${code.dump}
    '';
  };

  envAssignments = t: lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${q v}") t.env);

  expectOutput =
    label: file: needle:
    lib.optionalString (needle != null) ''
      if ! grep -qF -- ${q needle} ${file}; then
        report ${q label} "${file} does not contain ${q needle}" ${file}
      fi
    '';

  expectValues =
    label: t:
    lib.optionalString (t.expect != { } && t.exitCode == 0) ''
      if ! jq -e --argjson exp ${q (builtins.toJSON t.expect)} \
        '. as $act | $exp | to_entries | all(.value == $act[.key])' stdout.txt > /dev/null; then
        report ${q label} ${q "expected (subset) ${builtins.toJSON t.expect}"} stdout.txt
      fi
    '';

  runCase =
    i: t:
    let
      label = "case ${toString i} (${lib.escapeShellArgs t.argv})";
    in
    ''
      echo ${q "--- ${label}"}
      rc=0
      env -i PATH="$PATH" HOME="$TMPDIR" ${envAssignments t} ${harness} ${lib.escapeShellArgs t.argv} \
        > stdout.txt 2> stderr.txt || rc=$?
      if [ "$rc" -ne ${toString t.exitCode} ]; then
        report ${q label} "exit code $rc, expected ${toString t.exitCode}" stderr.txt
      fi
      ${expectOutput label "stdout.txt" t.stdoutContains}
      ${expectOutput label "stderr.txt" t.stderrContains}
      ${expectValues label t}
    '';
in
pkgs.runCommandLocal "${name}-args-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  failed=0
  report() {
    echo "FAIL $1: $2" >&2
    sed 's/^/  | /' "$3" >&2
    failed=1
  }
  ${util.joinLines (lib.imap1 runCase ir.tests)}
  [ "$failed" -eq 0 ]
  touch $out
''
