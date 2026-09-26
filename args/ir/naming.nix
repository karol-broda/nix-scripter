{ lib }:
rec {
  sanitize = lib.replaceStrings [ "-" ] [ "_" ];

  isIdentifier = s: builtins.match "[A-Za-z_][A-Za-z0-9_]*" s != null;

  shellSpecials = [
    "PATH"
    "IFS"
    "HOME"
    "PWD"
    "OLDPWD"
    "SHELL"
    "USER"
    "UID"
    "EUID"
    "PPID"
    "RANDOM"
    "LINENO"
    "SECONDS"
    "OPTIND"
    "OPTARG"
    "BASH"
    "BASH_ENV"
    "ENV"
    "CDPATH"
    "PS1"
    "PS2"
    "PS4"
    "TERM"
  ];

  applyCase =
    case: s:
    {
      upper = lib.toUpper s;
      lower = lib.toLower s;
      keep = s;
    }
    .${case};

  globalVariable =
    vars: argument:
    if argument.var != null then argument.var else vars.prefix + applyCase vars.case argument.key;

  listVariable = vars: argument: vars.listPrefix + argument.key;

  commandVariable =
    vars:
    globalVariable vars {
      key = vars.command;
      var = null;
    };
}
