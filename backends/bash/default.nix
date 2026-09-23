{ lib }:
let
  inherit (lib) concatStringsSep optional optionalString;
  q = lib.escapeShellArg;
  # always quoted, so values like `a-b` are never read as arithmetic (SC2100)
  sq = s: "'" + lib.replaceStrings [ "'" ] [ "'\\''" ] s + "'";

  caps32 = [
    "indexed-arrays"
    "printf-v"
    "err-trap"
  ];
  caps44 = caps32 ++ [
    "assoc-arrays"
    "namerefs"
    "fractional-read-timeout"
    "case-modification"
    "mapfile"
  ];
  caps5 = caps44 ++ [ "subsecond-time" ];

  targets = {
    "3.2" = {
      version = [
        3
        2
      ];
      caps = caps32;
    };
    "4.4" = {
      version = [
        4
        4
      ];
      caps = caps44;
    };
    "5" = {
      version = [
        5
        0
      ];
      caps = caps5;
    };
  };
in
{
  description = "GNU Bash";
  kind = "interpreted";
  extensions = [ "bash" ];
  tiers = [
    "P"
    "E"
  ];

  inherit targets;
  targetOf = config: config.bash.target;

  options =
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
            newer capabilities are rejected at build time; others degrade.
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
          description = "Shebang used in standalone mode.";
        };
      };
    };

  # Library function names in user code: `ns::fn`.
  scan =
    text:
    map
      (m: {
        ns = lib.elemAt m 0;
        fn = lib.elemAt m 1;
      })
      (lib.filter lib.isList (builtins.split "([A-Za-z_][A-Za-z0-9_]*)::([A-Za-z_][A-Za-z0-9_]*)" text));

  scanBare =
    names: text:
    lib.filter (
      n: builtins.match ".*(^|[^A-Za-z0-9_:.-])${n}([^A-Za-z0-9_:.-].*|$)" text != null
    ) names;

  naming = ns: fn: "${ns}::${fn}";

  argsStyle = target: if lib.elem "assoc-arrays" targets.${target}.caps then "assoc" else "globals";

  argsCodegen = (import ./args.nix { inherit lib; }).codegen;

  checkInterpreter = pkgs: "${pkgs.bash}/bin/bash";

  # Returns the list of segments making up the script. A segment is
  # { kind = "generated" | "library" | "user"; label; file?; text; }
  # or a deferred one { …; lines; render = layout: text; } whose content
  # depends on the final layout (used for the runtime source map).
  assemble =
    {
      config,
      features,
      args,
      linkedPath,
      startupCommands,
      user,
    }:
    let
      cfg = config.bash;
      target = targets.${cfg.target};
      major = toString (lib.elemAt target.version 0);
      minor = toString (lib.elemAt target.version 1);
      shebang =
        if config.mode == "linked" then "#!${cfg.package}/bin/bash" else "#!${cfg.standaloneShebang}";

      versionCheck = optionalString (config.mode == "standalone") ''
        if [ -z "''${BASH_VERSION:-}" ]; then
          printf '%s: error: this script must be run with bash\n' ${q config.name} >&2
          exit 1
        fi
        if [ "''${BASH_VERSINFO[0]}" -lt ${major} ] || { [ "''${BASH_VERSINFO[0]}" -eq ${major} ] && [ "''${BASH_VERSINFO[1]}" -lt ${minor} ]; }; then
          printf '%s: error: bash >= %s is required, this is %s\n' ${q config.name} ${q cfg.target} "$BASH_VERSION" >&2
          exit 1
        fi
      '';

      pathLine = optionalString (linkedPath != [ ]) (
        let
          p = q (concatStringsSep ":" linkedPath);
        in
        {
          prefix = ''export PATH=${p}"''${PATH:+:$PATH}"'';
          suffix = ''export PATH="''${PATH:+$PATH:}"${p}'';
          replace = "export PATH=${p}";
        }
        .${config.path}
      );

      commandCheck = optionalString (startupCommands != [ ]) ''
        __scripter_missing=
        for __scripter_c in ${concatStringsSep " " (map q startupCommands)}; do
          command -v "$__scripter_c" >/dev/null 2>&1 || __scripter_missing="$__scripter_missing $__scripter_c"
        done
        if [ -n "$__scripter_missing" ]; then
          printf '%s: error: missing required commands:%s\n' ${q config.name} "$__scripter_missing" >&2
          exit 127
        fi
        unset __scripter_c __scripter_missing
      '';

      envLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${q v}") config.env);

      prelude = lib.concatStringsSep "\n" (
        lib.filter (s: s != "") [
          shebang
          "# ${config.name} ${config.version} — generated by nix-scripter, do not edit"
          (optionalString cfg.strict "set -euo pipefail")
          versionCheck
          pathLine
          commandCheck
          envLines
          "__scripter_name=${sq config.name}"
          "__scripter_version=${sq config.version}"
          "__scripter_target=${sq cfg.target}"
        ]
      );

      # Runtime source map, used by core's error locations. Its line count is
      # fixed up front so the layout can be computed before rendering it.
      srcmapSegment = optional (lib.any (f: f.name == "core") features) {
        kind = "generated";
        label = "source map";
        lines = 2 + lib.length (lib.filter (s: s.kind == "user") body);
        render =
          layout:
          let
            users = lib.filter (s: s.kind == "user") layout;
          in
          concatStringsSep "\n" (
            [ "__scripter_srcmap=(" ]
            ++ map (s: "  ${q "${toString s.start} ${toString s.end} ${s.file}"}") users
            ++ [ ")" ]
          );
      };

      featureSegments = map (f: {
        kind = "library";
        label = "feature ${f.name}";
        text = f.code;
      }) features;

      argsSegments = optional (args != null) {
        kind = "generated";
        label = "argument parser";
        text = args.code.parser;
      };

      bodySegments = lib.concatMap (b: [
        {
          kind = "generated";
          label = "command ${concatStringsSep " " b.path}";
          text = "${b.name}() {";
        }
        {
          kind = "user";
          inherit (b) file;
          label = b.file;
          text = lib.removeSuffix "\n" b.text;
        }
        {
          kind = "generated";
          label = "command ${concatStringsSep " " b.path}";
          text = "}";
        }
      ]) (if args != null then args.code.bodies else [ ]);

      invokeSegment = optional (args != null) {
        kind = "generated";
        label = "argument parser";
        text = args.code.invoke;
      };

      mainSegment = {
        kind = "user";
        inherit (user) file;
        label = user.file;
        text = lib.removeSuffix "\n" user.text;
      };

      dispatchSegment = optional (args != null && args.code.dispatch != "") {
        kind = "generated";
        label = "command dispatch";
        text = args.code.dispatch;
      };

      body =
        featureSegments
        ++ argsSegments
        ++ bodySegments
        ++ invokeSegment
        ++ [ mainSegment ]
        ++ dispatchSegment;
    in
    [
      {
        kind = "generated";
        label = "prelude";
        text = prelude;
      }
    ]
    ++ srcmapSegment
    ++ body;
}
