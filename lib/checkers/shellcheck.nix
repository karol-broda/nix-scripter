{ lib }:
{
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
      excludes = lib.optionalString (cfg.exclude != [ ]) "-e ${lib.concatStringsSep "," cfg.exclude}";
    in
    ''
      rc=0
      shellcheck -s ${shell} -f json1 -S ${cfg.severity} ${excludes} ${lib.escapeShellArgs cfg.extraArgs} \
        "$source" > shellcheck.json || rc=$?
      if [ "$rc" -gt 1 ]; then
        cat shellcheck.json >&2
        exit "$rc"
      fi
      jq '[.comments[] | { line, column, level, code: ("SC" + (.code | tostring)), message }]' \
        shellcheck.json > "$diagnostics"
    '';
}
