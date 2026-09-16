# Bash code generation for the argument parser. Emits plain bash (3.2
# compatible) with no runtime dependencies. Values are parsed into internal
# variables first and exported in the configured style at the end, so the
# parser itself does not depend on the target.
{ lib }:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    filter
    optionalString
    ;

  q = lib.escapeShellArg;
  help = import ../../args/help.nix { inherit lib; };
  inherit (import ../../args/ir.nix { inherit lib; }) varName;

  v = key: "__scripter_av_${key}";
  g = key: "__scripter_ag_${key}";
  l = key: "__scripter_al_${key}";
  setter = key: "__scripter_args_set_${key}";
  parseFn = level: "__scripter_args_parse_${level.id}";
  finishFn = level: "__scripter_args_finish_${level.id}";
  helpFn = level: "__scripter_args_help_${level.id}";

  isList = a: (a.repeated or false) || (a.variadic or false);
  argsOf = level: level.inherited ++ level.flags ++ level.options;
  display = a: if a.kind == "positional" then "<${a.name}>" else "--${a.long}";

  levelsOf = level: [ level ] ++ lib.concatMap levelsOf level.commands;

  # -- shared runtime ------------------------------------------------------
  runtime = ''
    __scripter_args_error() {
      printf '%s: error: %s\n' "$__scripter_name" "$1" >&2
      if [ -n "''${3:-}" ]; then printf "\n  tip: did you mean '%s'?\n\n" "$3" >&2; fi
      printf "Try '%s --help' for more information.\n" "$2" >&2
      exit 2
    }

    # Levenshtein distance of $1 and $2 into __scripter_args_dist.
    __scripter_args_distance() {
      local a=$1 b=$2 i j cost del ins sub
      local -a prev cur
      for ((j = 0; j <= ''${#b}; j++)); do prev[j]=$j; done
      for ((i = 1; i <= ''${#a}; i++)); do
        cur=("$i")
        for ((j = 1; j <= ''${#b}; j++)); do
          if [ "''${a:i-1:1}" = "''${b:j-1:1}" ]; then cost=0; else cost=1; fi
          del=$((prev[j] + 1))
          ins=$((cur[j - 1] + 1))
          sub=$((prev[j - 1] + cost))
          if [ "$ins" -lt "$del" ]; then del=$ins; fi
          if [ "$sub" -lt "$del" ]; then del=$sub; fi
          cur[j]=$del
        done
        prev=("''${cur[@]}")
      done
      __scripter_args_dist=''${prev[''${#b}]}
    }

    # Closest candidate to $1 (distance <= 2, or a prefix) into __scripter_args_hint.
    __scripter_args_suggest() {
      local word=$1 best="" best_dist=3 c
      shift
      for c in "$@"; do
        case $c in "$word"*) __scripter_args_hint=$c; return 0 ;; esac
        __scripter_args_distance "$word" "$c"
        if [ "$__scripter_args_dist" -lt "$best_dist" ]; then
          best=$c
          best_dist=$__scripter_args_dist
        fi
      done
      __scripter_args_hint=$best
    }

    __scripter_args_check() {
      # $1 type, $2 value, $3 shown name, $4 command path, $5 pattern, rest: allowed values
      local type=$1 value=$2 name=$3 cmd=$4 pattern=$5 re
      shift 5
      case $type in
        int)
          re='^-?[0-9]+$'
          [[ $value =~ $re ]] || __scripter_args_error "invalid value '$value' for '$name': expected an integer" "$cmd"
          ;;
        float)
          re='^-?([0-9]+[.]?[0-9]*|[.][0-9]+)$'
          [[ $value =~ $re ]] || __scripter_args_error "invalid value '$value' for '$name': expected a number" "$cmd"
          ;;
        file)
          [ -f "$value" ] || __scripter_args_error "invalid value '$value' for '$name': no such file" "$cmd"
          ;;
        dir)
          [ -d "$value" ] || __scripter_args_error "invalid value '$value' for '$name': no such directory" "$cmd"
          ;;
        enum)
          local allowed
          for allowed in "$@"; do
            if [ "$allowed" = "$value" ]; then return 0; fi
          done
          __scripter_args_suggest "$value" "$@"
          __scripter_args_error "invalid value '$value' for '$name' (possible values: $*)" "$cmd" "''${__scripter_args_hint:-}"
          ;;
      esac
      if [ -n "$pattern" ] && ! [[ $value =~ $pattern ]]; then
        __scripter_args_error "invalid value '$value' for '$name': must match $pattern" "$cmd"
      fi
    }

    __scripter_args_bool() {
      # $1 value, $2 shown name, $3 command path; result in __scripter_args_b
      case $1 in
        1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy] | [Oo][Nn]) __scripter_args_b=1 ;;
        "" | 0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo] | [Nn] | [Oo][Ff][Ff]) __scripter_args_b= ;;
        *) __scripter_args_error "invalid boolean '$1' for '$2'" "$3" ;;
      esac
    }
  '';

  # -- per argument --------------------------------------------------------
  setterFor =
    a:
    let
      values = optionalString (a.values != null) " ${concatMapStringsSep " " q a.values}";
      check = "__scripter_args_check ${q a.type} \"$1\" \"$2\" \"$3\" ${
        q (if a.pattern != null then a.pattern else "")
      }${values}";
      assign = if isList a then "${l a.key}+=(\"$1\")" else "${v a.key}=$1";
    in
    ''
      ${setter a.key}() {
        ${check}
        ${assign}
        ${g a.key}=1
      }'';

  # case branches handling one flag/option at a level
  branches =
    level: a:
    let
      cmd = q level.display;
      shortFlagBundle = optionalString (a.short != null) ''
        -${a.short}?*)
          ${flagSet a}
          shift
          set -- "-''${__scripter_arg#-${a.short}}" "$@"
          continue
          ;;'';
      flagSet =
        a: if a.count then "${v a.key}=$((${v a.key} + 1)); ${g a.key}=1" else "${v a.key}=1; ${g a.key}=1";
      names = concatStringsSep " | " ([ "--${a.long}" ] ++ lib.optional (a.short != null) "-${a.short}");
    in
    if a.kind == "flag" then
      {
        exact = ''
          ${names})
            ${flagSet a}
            ;;
          --${a.long}=*)
            __scripter_args_error "option '--${a.long}' does not take a value" ${cmd}
            ;;''
        + optionalString a.negatable ''

          --no-${a.long})
            ${v a.key}=${if a.count then "0" else ""}; ${g a.key}=1
            ;;'';
        bundle = shortFlagBundle;
      }
    else
      {
        exact = ''
          ${names})
            [ "$#" -ge 2 ] || __scripter_args_error "option '$__scripter_arg' requires a value" ${cmd}
            ${setter a.key} "$2" "$__scripter_arg" ${cmd}
            shift
            ;;
          --${a.long}=*)
            ${setter a.key} "''${__scripter_arg#*=}" '--${a.long}' ${cmd}
            ;;'';
        bundle = optionalString (a.short != null) ''
          -${a.short}?*)
            ${setter a.key} "''${__scripter_arg#-${a.short}}" '-${a.short}' ${cmd}
            ;;'';
      };

  # -- per level -----------------------------------------------------------
  levelCode =
    ir: level:
    let
      cmd = q level.display;
      args = argsOf level;
      bs = map (branches level) args;
      longs =
        map (a: "--${a.long}") args
        ++ map (a: "--no-${a.long}") (filter (a: a.kind == "flag" && a.negatable) args)
        ++ lib.optional ir.globals.help "--help"
        ++ lib.optional (ir.globals.version && level.path == [ ]) "--version";
      commandNames = lib.concatMap (c: [ c.name ] ++ c.aliases) level.commands;
      pos = level.positional;
      required = lib.length (filter (p: !p.optional && !p.variadic) pos);
      fixed = filter (p: !p.variadic) pos;
      variadic = lib.findFirst (p: p.variadic) null pos;
      helpText = help.render ir level;

      commandBranch =
        if level.commands == [ ] then
          ''__scripter_pos+=("$__scripter_arg")''
        else
          ''
            case $__scripter_arg in
            ${concatMapStringsSep "\n" (c: ''
              ${concatMapStringsSep " | " q ([ c.name ] ++ c.aliases)})
                __scripter_args_command=${q (concatStringsSep " " c.path)}
                shift
                ${parseFn c} "$@"
                ${finishFn level}
                return 0
                ;;'') level.commands}
              *)
                __scripter_args_suggest "$__scripter_arg" ${concatMapStringsSep " " q commandNames}
                __scripter_args_error "unrecognized command '$__scripter_arg'" ${cmd} "''${__scripter_args_hint:-}"
                ;;
            esac'';

      positionalAssign = ''
        if [ "''${#__scripter_pos[@]}" -lt ${toString required} ]; then
          __scripter_args_error "missing required argument${optionalString (required > 1) "s"} ${
            concatMapStringsSep " " (p: "<${p.name}>") (filter (p: !p.optional && !p.variadic) pos)
          }" ${cmd}
        fi
        ${concatStringsSep "\n" (
          lib.imap0 (i: p: ''
            if [ "''${#__scripter_pos[@]}" -gt ${toString i} ]; then
              ${setter p.key} "''${__scripter_pos[${toString i}]}" '<${p.name}>' ${cmd}
            fi'') fixed
        )}
        ${
          if variadic != null then
            ''
              if [ "''${#__scripter_pos[@]}" -gt ${toString (lib.length fixed)} ]; then
                for __scripter_arg in "''${__scripter_pos[@]:${toString (lib.length fixed)}}"; do
                  ${setter variadic.key} "$__scripter_arg" '<${variadic.name}>' ${cmd}
                done
              fi''
          else
            ''
              if [ "''${#__scripter_pos[@]}" -gt ${toString (lib.length fixed)} ]; then
                __scripter_arg=''${__scripter_pos[${toString (lib.length fixed)}]}
                __scripter_args_error "unexpected argument '$__scripter_arg'" ${cmd}
              fi''
        }'';

      own = level.flags ++ level.options ++ pos;
      byName = n: lib.findFirst (a: a.name == n) (throw "unknown argument ${n}") own;
      given = a: "[ -n \"\${${g a.key}:-}\" ]";

      envFallback =
        a:
        optionalString (a.env != null) (
          if a.kind == "flag" then
            ''
              if [ -z "''${${g a.key}:-}" ] && [ -n "''${${a.env}:-}" ]; then
                ${
                  if a.count then
                    ''
                      __scripter_args_check int "''$${a.env}" "\''$${a.env}" ${cmd} ""
                      ${v a.key}=''$${a.env}''
                  else
                    ''
                      __scripter_args_bool "''$${a.env}" "\''$${a.env}" ${cmd}
                      ${v a.key}=$__scripter_args_b''
                }
                ${g a.key}=1
              fi''
          else
            ''
              if [ -z "''${${g a.key}:-}" ] && [ -n "''${${a.env}:-}" ]; then
                ${setter a.key} "''$${a.env}" "\''$${a.env}" ${cmd}
              fi''
        );

      defaultFor =
        a:
        optionalString (a.default != null) (
          if a.kind == "flag" then
            optionalString (a.default == true) ''if [ -z "''${${g a.key}:-}" ]; then ${v a.key}=1; fi''
          else if isList a then
            ''if [ -z "''${${g a.key}:-}" ]; then ${l a.key}=(${
              concatMapStringsSep " " q (lib.toList a.default)
            }); fi''
          else
            ''if [ -z "''${${g a.key}:-}" ]; then ${v a.key}=${q a.default}; fi''
        );

      requiredCheck =
        a:
        optionalString (a.required or false
        ) ''${given a} || __scripter_args_error "missing required option '--${a.long}'" ${cmd}'';

      constraint =
        c:
        let
          countGiven =
            names:
            "__scripter_n=0; "
            + concatMapStringsSep "; " (
              n: "if ${given (byName n)}; then __scripter_n=$((__scripter_n + 1)); fi"
            ) names;
          shown = names: concatMapStringsSep ", " (n: "'${display (byName n)}'") names;
        in
        optionalString (c.exclusive != null) ''
          ${countGiven c.exclusive}
          [ "$__scripter_n" -le 1 ] || __scripter_args_error "only one of ${shown c.exclusive} may be given" ${cmd}''
        + optionalString (c.oneOf != null) ''

          ${countGiven c.oneOf}
          [ "$__scripter_n" -eq 1 ] || __scripter_args_error "exactly one of ${shown c.oneOf} must be given" ${cmd}''
        + optionalString (c.requires != null) (
          concatStringsSep "\n" (
            lib.mapAttrsToList (
              n: deps:
              concatMapStringsSep "\n" (d: ''
                if ${given (byName n)} && ! ${given (byName d)}; then
                  __scripter_args_error "'${display (byName n)}' requires '${display (byName d)}'" ${cmd}
                fi'') deps
            ) c.requires
          )
        );

      action =
        a:
        optionalString (a.action != null) (
          {
            verbose = ''if [ "${"$"}${v a.key}" -gt 0 ]; then export SCRIPTER_LOG_LEVEL=debug; fi'';
            quiet = ''if [ -n "${"$"}${v a.key}" ]; then export SCRIPTER_LOG_LEVEL=warn; fi'';
            yes = ''if [ -n "${"$"}${v a.key}" ]; then export SCRIPTER_YES=1; fi'';
            dryRun = ''if [ -n "${"$"}${v a.key}" ]; then export SCRIPTER_DRY_RUN=1; fi'';
            color = ''if [ -n "${"$"}${v a.key}" ]; then export SCRIPTER_COLOR=${"$"}${v a.key}; fi'';
          }
          .${a.action}
        );
    in
    ''
      ${helpFn level}() {
        printf '%s\n' ${q helpText}
      }

      ${parseFn level}() {
        local __scripter_arg
        local -a __scripter_pos=()
        while [ "$#" -gt 0 ]; do
          __scripter_arg=$1
          case $__scripter_arg in
            --)
              shift
              while [ "$#" -gt 0 ]; do
                __scripter_pos+=("$1")
                shift
              done
              break
              ;;
            ${optionalString ir.globals.help ''
              -h | --help)
                ${helpFn level}
                exit 0
                ;;''}
            ${optionalString (ir.globals.version && level.path == [ ]) ''
              --version)
                printf '%s %s\n' "$__scripter_name" "$__scripter_version"
                exit 0
                ;;''}
      ${concatMapStringsSep "\n" (b: b.exact) bs}
      ${concatMapStringsSep "\n" (b: b.bundle) bs}
            ${optionalString ir.globals.help ''
              -h?*)
                ${helpFn level}
                exit 0
                ;;''}
            --*)
              __scripter_args_suggest "''${__scripter_arg%%=*}" ${concatMapStringsSep " " q longs}
              __scripter_args_error "unrecognized option '$__scripter_arg'" ${cmd} "''${__scripter_args_hint:-}"
              ;;
            -?*)
              __scripter_args_error "unrecognized option '$__scripter_arg'" ${cmd}
              ;;
            *)
              ${commandBranch}
              ;;
          esac
          shift
        done
        ${
          if level.commands != [ ] then
            ''__scripter_args_error "missing command (one of: ${
              concatStringsSep ", " (map (c: c.name) level.commands)
            })" ${cmd}''
          else
            ''
              ${positionalAssign}
              ${finishFn level}''
        }
      }

      ${finishFn level}() {
        local __scripter_n=0
        : "$__scripter_n"
        ${concatMapStringsSep "\n" envFallback own}
        ${concatMapStringsSep "\n" defaultFor own}
        ${concatMapStringsSep "\n" requiredCheck own}
        ${concatMapStringsSep "\n" constraint level.constraints}
        ${concatMapStringsSep "\n" action own}
      }
    '';

  # -- whole parser --------------------------------------------------------
  codegen =
    { ir }:
    let
      levels = levelsOf ir.root;
      allArgs = lib.unique (
        lib.concatMap (
          lv: map (a: removeAttrs a [ "description" ]) (lv.flags ++ lv.options ++ lv.positional)
        ) levels
      );
      byKey = lib.attrValues (lib.listToAttrs (map (a: lib.nameValuePair a.key a) allArgs));
      setters = map setterFor (filter (a: a.kind != "flag") byKey);
      init = concatMapStringsSep "\n" (
        a:
        if isList a then
          "${l a.key}=()\n${g a.key}="
        else
          "${v a.key}=${if a.kind == "flag" && a.count then "0" else ""}\n${g a.key}="
      ) byKey;

      inherit (ir) vars;
      assoc = vars.style == "assoc";
      exportLine =
        a:
        if isList a then
          "${vars.listPrefix}${a.key}=(\${${l a.key}[@]+\"\${${l a.key}[@]}\"})"
        else if assoc then
          "${vars.name}[${a.key}]=\"\$${v a.key}\""
        else
          "${varName vars a}=\"\$${v a.key}\"";
      commandVar =
        if assoc then
          "${vars.name}[${vars.command}]=\"$__scripter_args_command\""
        else
          "${
            varName vars {
              key = vars.command;
              var = null;
            }
          }=\"$__scripter_args_command\"";
    in
    {
      parser = ''
        ${runtime}
        ${concatStringsSep "\n\n" setters}

        ${concatMapStringsSep "\n" (levelCode ir) levels}

        ${init}
        __scripter_args_command=
        ${optionalString assoc "declare -A ${vars.name}=()"}

        # shellcheck disable=SC2034
        __scripter_args_export() {
          ${concatMapStringsSep "\n" exportLine byKey}
          ${commandVar}
        }
      '';

      invoke = ''
        __scripter_args_parse_root "$@"
        __scripter_args_export'';

      # Runs subcommand bodies (form A) or cmd::<path> functions (form B).
      dispatch =
        let
          leaves = filter (lv: lv.path != [ ] && lv.commands == [ ]) levels;
          fnOf = lv: "cmd::${concatStringsSep "::" lv.path}";
        in
        optionalString ir.hasCommands ''
          case $__scripter_args_command in
          ${concatMapStringsSep "\n" (
            lv:
            if lv.body != null then
              "${q (concatStringsSep " " lv.path)}) __scripter_cmd_${lv.id} ;;"
            else
              ''
                ${q (concatStringsSep " " lv.path)})
                  if declare -F ${fnOf lv} >/dev/null; then
                    ${fnOf lv}
                  else
                    printf '%s: error: command %s has no implementation (define %s)\n' "$__scripter_name" ${q lv.display} ${q (fnOf lv)} >&2
                    exit 70
                  fi
                  ;;''
          ) leaves}
          esac'';

      bodies = map (lv: {
        name = "__scripter_cmd_${lv.id}";
        inherit (lv.body) text file;
        path = lv.path;
      }) (filter (lv: lv.body != null) levels);

      # JSON dump of all parsed values, used by arg tests.
      dump =
        let
          jsonValue =
            a:
            if isList a then
              ''
                printf '['
                __scripter_sep=
                for __scripter_x in ''${${l a.key}[@]+"''${${l a.key}[@]}"}; do
                  printf '%s' "$__scripter_sep"; __scripter_json ${
                    if
                      lib.elem a.type [
                        "int"
                        "float"
                      ]
                    then
                      "num"
                    else
                      "str"
                  } "$__scripter_x"; __scripter_sep=,
                done
                printf ']\n' ''
            else if a.kind == "flag" then
              if a.count then
                ''__scripter_json num "''$${v a.key}"''
              else
                ''if [ -n "''$${v a.key}" ]; then printf true; else printf false; fi''
            else
              ''__scripter_json ${
                if
                  lib.elem a.type [
                    "int"
                    "float"
                  ]
                then
                  "num"
                else
                  "str"
              } "''$${v a.key}"'';
          entries = map (a: ''
            printf '%s:' ${q (builtins.toJSON a.key)}
            ${jsonValue a}
            printf ','
          '') byKey;
        in
        ''
          __scripter_json() {
            local s=$2
            if [ -z "$s" ]; then printf null; return 0; fi
            if [ "$1" = num ]; then printf '%s' "$s"; return 0; fi
            s=''${s//\\/\\\\}
            s=''${s//\"/\\\"}
            s=''${s//$'\n'/\\n}
            s=''${s//$'\t'/\\t}
            s=''${s//$'\r'/\\r}
            printf '"%s"' "$s"
          }
          printf '{'
          ${concatStringsSep "\n" entries}
          printf '"_command":'
          __scripter_json str "$__scripter_args_command"
          printf '}\n'
        '';
    };
in
{
  inherit codegen;
}
