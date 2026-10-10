__scripter_args_error() {
  printf '%s: error: %s\n' "$__scripter_name" "$1" >&2
  if [ -n "${2:-}" ]; then printf "\n  tip: did you mean '%s'?\n\n" "$2" >&2; fi
  printf "Try '%s --help' for more information.\n" "$__scripter_args_cmd" >&2
  exit 2
}
__scripter_args_distance() {
  local a=$1 b=$2 i j cost del ins sub
  local -a prev cur
  for ((j = 0; j <= ${#b}; j++)); do prev[j]=$j; done
  for ((i = 1; i <= ${#a}; i++)); do
    cur=("$i")
    for ((j = 1; j <= ${#b}; j++)); do
      if [ "${a:i-1:1}" = "${b:j-1:1}" ]; then cost=0; else cost=1; fi
      del=$((prev[j] + 1))
      ins=$((cur[j - 1] + 1))
      sub=$((prev[j - 1] + cost))
      if [ "$ins" -lt "$del" ]; then del=$ins; fi
      if [ "$sub" -lt "$del" ]; then del=$sub; fi
      cur[j]=$del
    done
    prev=("${cur[@]}")
  done
  __scripter_args_dist=${prev[${#b}]}
}
__scripter_args_suggest() {
  local word=$1 best="" best_dist=3 c
  shift
  for c in "$@"; do
    case $c in "$word"*)
      __scripter_args_hint=$c
      return 0
      ;;
    esac
    __scripter_args_distance "$word" "$c"
    if [ "$__scripter_args_dist" -lt "$best_dist" ]; then
      best=$c
      best_dist=$__scripter_args_dist
    fi
  done
  __scripter_args_hint=$best
}
