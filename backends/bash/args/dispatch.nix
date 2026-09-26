{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };

  commandPath = level: q (lib.concatStringsSep " " level.path);

  bodyBranch = level: "${commandPath level}) ${names.commandBody level} ;;";

  functionBranch = level: ''
    ${commandPath level})
      if declare -F ${names.commandFunction level} >/dev/null; then
        ${names.commandFunction level}
      else
        __scripter_args_missing_implementation ${q level.display} ${q (names.commandFunction level)}
      fi
      ;;'';

  branch = level: if level.body != null then bodyBranch level else functionBranch level;

  isLeafCommand = level: !level.isRoot && level.commands == [ ];
in
{
  dispatch =
    ir: allLevels:
    lib.optionalString ir.hasCommands ''
      case $__scripter_args_command in
      ${lib.concatMapStringsSep "\n" branch (lib.filter isLeafCommand allLevels)}
      esac'';

  bodies =
    allLevels:
    map (level: {
      name = names.commandBody level;
      inherit (level.body) text file;
      inherit (level) path;
    }) (lib.filter (level: level.body != null) allLevels);
}
