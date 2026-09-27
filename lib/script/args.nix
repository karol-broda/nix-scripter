{ lib, ... }:
{
  options.args = lib.mkOption {
    description = "Command line interface: parser, help and completions.";
    default = { };
    type = lib.types.submodule (import ../../args/types { inherit lib; }).root;
  };
}
