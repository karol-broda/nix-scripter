{ lib, name }:
segments:
let
  inherit (import ../util.nix { inherit lib; }) lineCount;

  withoutTrailingNewline = s: if s ? text then s // { text = lib.removeSuffix "\n" s.text; } else s;

  place =
    acc: segment:
    let
      lines = segment.lines or (lineCount segment.text);
    in
    {
      next = acc.next + lines;
      placed = acc.placed ++ [
        (
          segment
          // {
            start = acc.next;
            end = acc.next + lines - 1;
          }
        )
      ];
    };

  placed =
    (lib.foldl' place {
      next = 1;
      placed = [ ];
    } (map withoutTrailingNewline segments)).placed;

  render =
    segment:
    if segment ? render then
      let
        text = segment.render placed;
      in
      assert lib.assertMsg (
        lineCount text == segment.lines
      ) "${name}: segment `${segment.label}` rendered the wrong number of lines";
      text
    else
      segment.text;

  origin =
    s:
    {
      inherit (s) kind label;
    }
    // lib.optionalAttrs (s ? file) { inherit (s) file; };
in
{
  source = lib.concatMapStringsSep "\n" render placed + "\n";

  sourceMap = {
    version = 1;
    file = name;
    segments = map (s: {
      inherit (s) start end;
      origin = origin s;
    }) placed;
  };
}
