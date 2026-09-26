__scripter_json() {
  local s=$2
  if [ -z "$s" ]; then
    printf null
    return 0
  fi
  if [ "$1" = num ]; then
    printf '%s' "$s"
    return 0
  fi
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  printf '"%s"' "$s"
}

__scripter_json_flag() {
  if [ -n "$1" ]; then printf true; else printf false; fi
}

__scripter_json_list() {
  local kind=$1 sep="" item
  shift
  printf '['
  for item in "$@"; do
    printf '%s' "$sep"
    __scripter_json "$kind" "$item"
    sep=,
  done
  printf ']'
}
