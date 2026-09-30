{ scripterLib, top }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.scripter;

  boolOption =
    default: description:
    mkOption {
      type = types.bool;
      inherit default description;
    };

  discovered = lib.optionalAttrs cfg.discover.enable (
    cfg.instance.discover { inherit (cfg.discover) dir shLang prefix; }
  );

  modulesByName = lib.zipAttrsWith (_: modules: modules) [
    discovered
    top.scripts
    cfg.scripts
  ];

  buildScript =
    name: modules:
    cfg.instance.mkScript {
      imports = modules;
      name = lib.mkDefault name;
    };

  supported = _: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv;

  scriptChecks = lib.concatMapAttrs (
    name: drv:
    {
      "scripter-${name}" = drv;
    }
    // lib.mapAttrs' (check: value: lib.nameValuePair "scripter-${name}-${check}" value) drv.checks
  ) cfg.packages;
in
{
  options.scripter = {
    pkgs = mkOption {
      type = types.raw;
      default = pkgs;
      defaultText = lib.literalExpression "pkgs";
      description = "Package set scripts are built with.";
    };
    defaults = mkOption {
      type = types.deferredModule;
      default = { };
      description = "Module applied to every script on this system.";
    };
    scripts = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
    };

    discover = {
      enable = boolOption false "Build every script found in `dir` (see `lib.discover`).";
      dir = mkOption { type = types.path; };
      shLang = mkOption {
        type = types.str;
        default = "bash";
        description = "Backend used for `.sh` files.";
      };
      prefix = mkOption {
        type = types.str;
        default = "";
      };
    };

    expose = {
      packages = boolOption true "Add scripts to `packages`.";
      apps = boolOption true "Add scripts to `apps`.";
      checks = boolOption true "Add scripts and their checks to `checks`.";
      default = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Script exposed as `packages.default` and `apps.default`.";
      };
    };

    instance = mkOption {
      type = types.raw;
      readOnly = true;
      description = "The scripter instance for this system, with defaults and extensions applied.";
    };
    packages = mkOption {
      type = types.lazyAttrsOf types.package;
      readOnly = true;
      description = "All scripts supported on this system, by name.";
    };
  };

  config = {
    scripter.instance = scripterLib.mkScripter {
      inherit (cfg) pkgs;
      inherit (top) extensions;
      modules = [
        top.defaults
        cfg.defaults
      ];
    };

    scripter.packages = lib.filterAttrs supported (lib.mapAttrs buildScript modulesByName);

    _module.args.scripter = cfg.instance;

    packages = lib.mkIf cfg.expose.packages (
      cfg.packages
      // lib.optionalAttrs (cfg.expose.default != null) { default = cfg.packages.${cfg.expose.default}; }
    );

    apps = lib.mkIf cfg.expose.apps (
      lib.mapAttrs (_: drv: drv.app) cfg.packages
      // lib.optionalAttrs (cfg.expose.default != null) {
        default = cfg.packages.${cfg.expose.default}.app;
      }
    );

    checks = lib.mkIf cfg.expose.checks scriptChecks;
  };
}
