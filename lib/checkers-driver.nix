# Wraps a checker's command into a shell snippet that reports diagnostics
# against the user's files and fails on any finding.
{ lib, pkgs }:
{
  run =
    {
      name,
      cname,
      c,
      cfg,
      config,
      sourceFile,
      sourceMapFile,
      userSourceFile,
    }:
    {
      packages = [ pkgs.jq ] ++ c.packages pkgs;
      script = ''
        (
          set -euo pipefail
          source=${sourceFile}
          userSource=${userSourceFile}
          diagnostics=$(mktemp)
          echo '[]' > "$diagnostics"
          cd "$(mktemp -d)"
          ${c.command { inherit cfg config; }}
          ${lib.optionalString ((c.output or "diagnostics") == "diagnostics") ''
            if [ "$(jq length "$diagnostics")" -gt 0 ]; then
              echo "${name}: ${cname} found problems:" >&2
              jq -r --slurpfile map ${sourceMapFile} -f ${./remap.jq} "$diagnostics" >&2
              exit 1
            fi
          ''}
        )
      '';
    };
}
