{ lib }:
{
  description = "Parse the generated script with the test interpreter (`bash -n`).";
  backends = [ "bash" ];
  defaultEnable = true;
  defaultStage = "build";
  packages = _: [ ];
  command =
    { config, ... }:
    ''
      rc=0
      ${config.bash.testPackage}/bin/bash -n "$source" 2> syntax.err || rc=$?
      jq -R -s '[split("\n")[] | select(test("line [0-9]+: "))
                | capture("line (?<line>[0-9]+): (?<message>.*)")
                | { line: (.line | tonumber), column: 0, level: "error", code: null, message }]' \
        syntax.err > "$diagnostics"
      if [ "$rc" -ne 0 ] && [ "$(jq length "$diagnostics")" -eq 0 ]; then
        jq -R -s '[{ line: 0, column: 0, level: "error", code: null, message: . }]' syntax.err > "$diagnostics"
      fi
    '';
}
