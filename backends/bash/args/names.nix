{ lib }:
rec {
  value = key: "__scripter_av_${key}";
  list = key: "__scripter_al_${key}";
  setter = level: a: "__scripter_args_set_${level.id}__${a.key}";

  table = kind: level: "__scripter_args_${kind}_${level.id}";
  parse = level: "__scripter_args_parse_${level.id}";
  finish = level: "__scripter_args_finish_${level.id}";
  help = level: "__scripter_args_help_${level.id}";
  commandBody = level: "__scripter_cmd_${level.id}";
  commandFunction = level: "cmd::${lib.concatStringsSep "::" level.path}";

  valueRef = a: "\"\$${value a.key}\"";
  listRef = a: "\${${list a.key}[@]+\"\${${list a.key}[@]}\"}";

  shown = a: if a.kind == "positional" then "<${a.name}>" else "--${a.long}";
}
