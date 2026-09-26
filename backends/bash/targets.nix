let
  bash32 = [
    "indexed-arrays"
    "printf-v"
    "err-trap"
  ];
  bash44 = bash32 ++ [
    "assoc-arrays"
    "namerefs"
    "fractional-read-timeout"
    "case-modification"
    "mapfile"
  ];
  bash5 = bash44 ++ [ "subsecond-time" ];
in
{
  "3.2" = {
    version = [
      3
      2
    ];
    caps = bash32;
  };
  "4.4" = {
    version = [
      4
      4
    ];
    caps = bash44;
  };
  "5" = {
    version = [
      5
      0
    ];
    caps = bash5;
  };
}
