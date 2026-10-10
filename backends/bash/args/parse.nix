{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  inherit (import ../../../lib/util.nix { inherit lib; }) shellQuote;
  inherit (import ./tables.nix { inherit lib; }) optionLevels;

  isLeaf = level: level.commands == [ ];
  hasFinish = level: (import ./finish.nix { inherit lib; }).rulesFor level != [ ];
in
{
  parseFunction =
    allLevels: level:
    lib.concatStringsSep "\n" (
      [
        "${names.parse level}() {"
        "  __scripter_args_cmd=${shellQuote level.display}"
        "  __scripter_args_parse_level ${level.id} ${q (optionLevels allLevels level)} \"$@\""
      ]
      ++ lib.optional (isLeaf level) "  __scripter_args_assign_positionals ${level.id}"
      ++ lib.optional (hasFinish level) "  ${names.finish level}"
      ++ [ "}" ]
    );

  # Help text is printed verbatim, so `$` in descriptions is intended.
  helpFunction =
    { parts, sharedSection }:
    level:
    let
      print = text: lib.optional (text != "") "  printf '%s' ${q text}";
    in
    lib.concatStringsSep "\n" (
      [
        "# shellcheck disable=SC2016"
        "${names.help level}() {"
      ]
      ++ print parts.own
      ++ lib.optional (parts.inherited != "") "  ${sharedSection parts.inherited}"
      ++ print parts.examples
      ++ [ "}" ]
    );

  inherit hasFinish;
}
