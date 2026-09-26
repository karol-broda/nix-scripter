{ lib }:
rec {
  # Always quoted, unlike lib.escapeShellArg: shellcheck reads `x=a-b` as arithmetic (SC2100).
  shellQuote = s: "'" + lib.replaceStrings [ "'" ] [ "'\\''" ] s + "'";

  readFiles = files: lib.concatMapStringsSep "\n" builtins.readFile files;

  lineCount = text: lib.length (lib.splitString "\n" text);

  padRight = width: s: s + lib.concatStrings (lib.genList (_: " ") (width - lib.stringLength s));

  duplicates = xs: lib.unique (lib.filter (x: lib.count (y: y == x) xs > 1) xs);

  withoutModuleAttrs = attrs: removeAttrs attrs [ "_module" ];

  joinLines = lib.concatStringsSep "\n";

  bulletList = lines: joinLines (map (l: "  - ${l}") lines);
}
