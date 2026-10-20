{ pkgs }:
{
  runTest =
    name: packages: script:
    pkgs.runCommandLocal "test-${name}"
      {
        nativeBuildInputs = [
          pkgs.gnugrep
          pkgs.diffutils
        ]
        ++ packages;
      }
      ''
        set -euo pipefail
        fail() { echo "FAIL: $*" >&2; exit 1; }
        expect_contains() { grep -qF -- "$2" "$1" || { echo "--- $1:" >&2; cat "$1" >&2; fail "$1 does not contain: $2"; }; }
        expect_not_contains() { if grep -qF -- "$2" "$1"; then cat "$1" >&2; fail "$1 contains: $2"; fi; }
        ${script}
        touch $out
      '';

  failsToEvaluate = drv: !(builtins.tryEval (builtins.seq drv.drvPath true)).success;

  # Runs a command attached to a pseudo-terminal, on Linux and darwin alike.
  inTerminal = pkgs.writeShellScript "in-terminal" ''
    exec ${pkgs.python3.interpreter} -c '
    import os, pty, sys
    sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))
    ' "$@"
  '';
}
