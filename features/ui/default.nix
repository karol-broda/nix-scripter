{ lib }:
let
  colorCodes = {
    none = "";
    bold = "1";
    dim = "2";
    black = "30";
    red = "31";
    green = "32";
    yellow = "33";
    blue = "34";
    magenta = "35";
    cyan = "36";
    white = "37";
    gray = "90";
    bright-red = "91";
    bright-green = "92";
    bright-yellow = "93";
    bright-blue = "94";
    bright-magenta = "95";
    bright-cyan = "96";
  };
  colors = lib.attrNames colorCodes;
  escapeCode = color: if colorCodes.${color} == "" then "\"\"" else "$'\\e[${colorCodes.${color}}m'";
  q = lib.escapeShellArg;
  inherit (import ../../lib/util.nix { inherit lib; }) readFiles;
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
        "sed"
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
        lib.mapAttrsToList (role: color: "__scripter_ui_theme_${role}=${escapeCode color}") (
          removeAttrs cfg.theme [ "_module" ]
        )
      )}
    ''
    + readFiles [
      ./style.bash
      ./ci.bash
      ./messages.bash
      ./layout.bash
      ./table.bash
      ./prompts.bash
      ./choose.bash
      ./groups.bash
      ./timing.bash
      ./spin.bash
      ./progress.bash
    ];
}
