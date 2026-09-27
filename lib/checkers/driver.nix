{ lib, pkgs }:
let
  reportDiagnostics =
    {
      script,
      checkerName,
      files,
    }:
    ''
      if [ "$(jq length "$diagnostics")" -gt 0 ]; then
        echo "${script}: ${checkerName} found problems:" >&2
        jq -r --slurpfile map ${files.sourceMap} -f ${./remap.jq} "$diagnostics" >&2
        exit 1
      fi
    '';
in
{
  run =
    {
      script,
      checkerName,
      checker,
      cfg,
      config,
      files,
    }:
    {
      packages = [ pkgs.jq ] ++ checker.packages pkgs;
      script = ''
        (
          set -euo pipefail
          source=${files.source}
          userSource=${files.userSource}
          diagnostics=$(mktemp)
          echo '[]' > "$diagnostics"
          cd "$(mktemp -d)"
          ${checker.command { inherit cfg config; }}
          ${lib.optionalString ((checker.output or "diagnostics") == "diagnostics") (reportDiagnostics {
            inherit script checkerName files;
          })}
        )
      '';
    };
}
