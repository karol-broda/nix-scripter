{ lib }:
rec {
  value = key: "__scripter_av_${key}";
  given = key: "__scripter_ag_${key}";
  list = key: "__scripter_al_${key}";
  setter = key: "__scripter_args_set_${key}";

  parse = level: "__scripter_args_parse_${level.id}";
  finish = level: "__scripter_args_finish_${level.id}";
  help = level: "__scripter_args_help_${level.id}";
  commandBody = level: "__scripter_cmd_${level.id}";
  commandFunction = level: "cmd::${lib.concatStringsSep "::" level.path}";

  valueRef = a: "\"\$${value a.key}\"";
  givenRef = a: "\"\${${given a.key}:-}\"";
  listRef = a: "\${${list a.key}[@]+\"\${${list a.key}[@]}\"}";
  isGiven = a: "[ -n ${givenRef a} ]";

  shown = a: if a.kind == "positional" then "<${a.name}>" else "--${a.long}";
}
