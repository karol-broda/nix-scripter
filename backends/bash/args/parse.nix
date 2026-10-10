{ lib }:
let
  q = lib.escapeShellArg;
  names = import ./names.nix { inherit lib; };
  inherit (import ./tables.nix { inherit lib; }) optionLevels;

  # Help is printed verbatim, so a `$` in a description is intended.
  literal =
    name: text:
    lib.optionalString (text != "") (
      lib.optionalString (lib.hasInfix "$" text) "# shellcheck disable=SC2016\n" + "${name}=${q text}"
    );
in
{
  levelDescriptor =
    allLevels: section: level:
    let
      fields = [
        level.display
        (optionLevels allLevels level)
        (if section == null then "" else toString section)
      ];
    in
    "${names.table "level" level}=${q (lib.concatStringsSep "|" fields)}";

  helpVariables =
    parts: level:
    lib.concatStringsSep "\n" (
      lib.filter (s: s != "") [
        (literal (names.table "help" level) parts.own)
        (literal (names.table "examples" level) parts.examples)
      ]
    );

  sharedSection = index: text: literal "__scripter_args_help_section_${toString index}" text;
}
