# Built-in checkers. A checker's `command` is a shell snippet that can use
#   $source       the assembled script
#   $userSource   the user's own source (main text only)
#   $diagnostics  a file to write a JSON array of
#                 { line; column; level; code; message; } into
# Diagnostics are mapped back to the user's files through the source map.
# Checkers with `output = "raw"` report themselves and exit non-zero.
{ lib }:
{
  syntax = {
    description = "Parse the generated script with the interpreter (`bash -n`).";
    backends = [ "bash" ];
    defaultEnable = true;
    defaultStage = "build";
    packages = pkgs: [ pkgs.bash ];
    command =
      { ... }:
      ''
        rc=0
        bash -n "$source" 2> syntax.err || rc=$?
        jq -R -s '[split("\n")[] | select(test("line [0-9]+: "))
                  | capture("line (?<line>[0-9]+): (?<message>.*)")
                  | { line: (.line | tonumber), column: 0, level: "error", code: null, message }]' \
          syntax.err > "$diagnostics"
        if [ "$rc" -ne 0 ] && [ "$(jq length "$diagnostics")" -eq 0 ]; then
          jq -R -s '[{ line: 0, column: 0, level: "error", code: null, message: . }]' syntax.err > "$diagnostics"
        fi
      '';
  };

  shellcheck = {
    description = "ShellCheck on the generated script.";
    backends = [ "bash" ];
    defaultEnable = true;
    defaultStage = "build";
    packages = pkgs: [ pkgs.shellcheck ];
    options =
      { lib, ... }:
      {
        options = {
          exclude = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "SC[0-9]+");
            default = [ ];
            example = [ "SC2034" ];
          };
          severity = lib.mkOption {
            type = lib.types.enum [
              "error"
              "warning"
              "info"
              "style"
            ];
            default = "style";
            description = "Minimum severity reported.";
          };
          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      };
    command =
      { cfg, config }:
      let
        shell = if config.lang == "sh" then "sh" else "bash";
      in
      ''
        rc=0
        shellcheck -s ${shell} -f json1 -S ${cfg.severity} \
          ${lib.optionalString (cfg.exclude != [ ]) "-e ${lib.concatStringsSep "," cfg.exclude}"} \
          ${lib.escapeShellArgs cfg.extraArgs} "$source" > shellcheck.json || rc=$?
        if [ "$rc" -gt 1 ]; then
          cat shellcheck.json >&2
          exit "$rc"
        fi
        jq '[.comments[] | { line, column, level, code: ("SC" + (.code | tostring)), message }]' \
          shellcheck.json > "$diagnostics"
      '';
  };

  shfmt = {
    description = "Check that the user's source is formatted with shfmt.";
    backends = [ "bash" ];
    defaultEnable = false;
    defaultStage = "flake-check";
    packages = pkgs: [ pkgs.shfmt ];
    output = "raw";
    options =
      { lib, ... }:
      {
        options.args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "-i"
            "2"
            "-ci"
          ];
        };
      };
    command =
      { cfg, ... }:
      ''
        shfmt -ln bash ${lib.escapeShellArgs cfg.args} -d "$userSource"
      '';
  };
}
