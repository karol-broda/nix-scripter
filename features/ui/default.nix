{ lib }:
let
  colors = [
    "none"
    "bold"
    "dim"
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
    "gray"
    "bright-red"
    "bright-green"
    "bright-yellow"
    "bright-blue"
    "bright-magenta"
    "bright-cyan"
  ];
  q = lib.escapeShellArg;
in
{
  description = "Messages, prompts, groups, tables and spinners that render correctly for terminals, pipes and CI.";
  namespace = "ui";
  requires = [
    "core"
    "ctx"
  ];

  options =
    { lib, ... }:
    {
      options = {
        icons = lib.mkOption {
          type = lib.types.enum [
            "ascii"
            "unicode"
            "nerdfont"
          ];
          default = "ascii";
          description = "Icon set; SCRIPTER_ICONS overrides it at runtime.";
        };
        kvWidth = lib.mkOption {
          type = lib.types.ints.positive;
          default = 20;
          description = "Key column width of `ui::kv`.";
        };
        theme = lib.mkOption {
          type = lib.types.submodule {
            options =
              lib.mapAttrs
                (
                  _: default:
                  lib.mkOption {
                    type = lib.types.enum colors;
                    inherit default;
                  }
                )
                {
                  debug = "gray";
                  info = "blue";
                  success = "green";
                  warn = "yellow";
                  error = "red";
                  accent = "cyan";
                };
          };
          default = { };
          description = "Colors per message kind.";
        };
      };
    };

  functions = {
    debug = { };
    info = { };
    warn = { };
    error = { };
    success = { };
    header = { };
    section = { };
    kv = { };
    list = { };
    confirm = { };
    prompt = { };
    secret = { };
    group = { };
    group_begin = { };
    group_end = { };
    annotate = { };
    mask = { };
    summary.commands = [ "cat" ];
    table = {
      tier = "E";
      needs = [ "indexed-arrays" ];
      commands = [ "cat" ];
    };
    choose = {
      tier = "E";
      needs = [ "indexed-arrays" ];
    };
    spin = {
      tier = "E";
      needs = [ "indexed-arrays" ];
      commands = [
        "mktemp"
        "sleep"
        "rm"
        "cat"
      ];
    };
    progress = {
      tier = "E";
      needs = [ ];
    };
  };

  impl.bash =
    { cfg, args, ... }:
    let
      yesHint =
        if args != null && args.root.flags != [ ] && lib.any (f: f.action == "yes") args.root.flags then
          "pass --yes or set SCRIPTER_YES=1"
        else
          "set SCRIPTER_YES=1";
    in
    ''
      __scripter_ui_icons_default=${q cfg.icons}
      __scripter_ui_kv_width=${toString cfg.kvWidth}
      __scripter_ui_yes_hint=${q yesHint}
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (role: color: "__scripter_ui_theme_${role}=${q color}") (
          removeAttrs cfg.theme [ "_module" ]
        )
      )}
    ''
    + builtins.readFile ./ui.bash;
}
