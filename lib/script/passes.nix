{ lib, ... }:
{
  options.passes.treeShake = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Remove library functions the script cannot reach. Calls are found by
        name, so a function only called through a computed name
        (`"ui::$level"`) has to be listed in `keep`.
      '';
    };
    keep = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "ui::warn" ];
      description = "Functions to keep even when no call to them is found.";
    };
  };
}
