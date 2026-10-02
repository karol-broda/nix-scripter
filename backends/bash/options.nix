{ targets }:
{
  lib,
  pkgs,
  script,
  ...
}:
{
  options = {
    target = lib.mkOption {
      type = lib.types.enum (lib.attrNames targets);
      default = if script.mode == "linked" then "5" else "4.4";
      defaultText = lib.literalMD "`\"5\"` when linked (pinned bash), `\"4.4\"` when standalone";
      description = ''
        Oldest bash the script must run on. Library functions that need
        newer capabilities are rejected at build time, others degrade.
        `"3.2"` is macOS' /bin/bash.
      '';
    };
    strict = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "`set -euo pipefail`.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bashNonInteractive or pkgs.bash;
      defaultText = lib.literalExpression "pkgs.bashNonInteractive";
      description = "Interpreter used in linked mode.";
    };
    standaloneShebang = lib.mkOption {
      type = lib.types.str;
      default = "/usr/bin/env bash";
    };
    testPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bash;
      defaultText = lib.literalExpression "pkgs.bash";
      description = ''
        Interpreter for the syntax check and argument tests. Point it at a
        bash matching `target` to test compatibility for real.
      '';
    };
  };
}
