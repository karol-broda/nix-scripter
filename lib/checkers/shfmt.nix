{ lib }:
{
  description = "Check that the user's source is formatted with shfmt.";
  backends = [ "bash" ];
  defaultEnable = false;
  defaultStage = "flake-check";
  packages = pkgs: [ pkgs.shfmt ];
  output = "raw";

  options =
    { lib, ... }:
    {
      options.args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "-i"
          "2"
          "-ci"
        ];
      };
    };

  command =
    { cfg, ... }:
    ''
      shfmt -ln bash ${lib.escapeShellArgs cfg.args} -d "$userSource"
    '';
}
