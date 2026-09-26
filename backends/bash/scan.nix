{ lib }:
let
  namespacedCall = "([A-Za-z_][A-Za-z0-9_]*)::([A-Za-z_][A-Za-z0-9_]*)";
  boundary = "[^A-Za-z0-9_:.-]";
  matches = pattern: text: lib.any lib.isList (builtins.split pattern text);
in
{
  namespaced =
    text:
    map (m: {
      ns = lib.elemAt m 0;
      fn = lib.elemAt m 1;
    }) (lib.filter lib.isList (builtins.split namespacedCall text));

  bare = names: text: lib.filter (n: matches "(^|${boundary})${n}(${boundary}|$)" text) names;
}
