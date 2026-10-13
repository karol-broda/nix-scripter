__scripter_detect_forced_ci() {
  case ${SCRIPTER_CI:-} in
    none | 0 | false)
      __scripter_ci=""
      return 0
      ;;
    ?*)
      __scripter_ci=$SCRIPTER_CI
      return 0
      ;;
  esac
  return 1
}

__scripter_detect_ci_from_env() {
  if [ -n "${FORGEJO_ACTIONS:-}" ] || [ -n "${GITEA_ACTIONS:-}" ]; then
    __scripter_ci=forgejo
  elif [ "${GITHUB_ACTIONS:-}" = true ]; then
    __scripter_ci=github
  elif [ -n "${GITLAB_CI:-}" ]; then
    __scripter_ci=gitlab
  elif [ "${BUILDKITE:-}" = true ]; then
    __scripter_ci=buildkite
  elif [ -n "${TF_BUILD:-}" ]; then
    __scripter_ci=azure
  elif [ -n "${TEAMCITY_VERSION:-}" ]; then
    __scripter_ci=teamcity
  elif [ -n "${JENKINS_URL:-}" ]; then
    __scripter_ci=jenkins
  elif [ -n "${CIRCLECI:-}" ]; then
    __scripter_ci=circleci
  elif [ "${CI:-}" = woodpecker ]; then
    __scripter_ci=woodpecker
  elif [ -n "${DRONE:-}" ]; then
    __scripter_ci=drone
  else
    case ${CI:-} in
      '' | 0 | false | False | FALSE) __scripter_ci="" ;;
      *) __scripter_ci=generic ;;
    esac
  fi
}

__scripter_ensure_ci() {
  if [ -n "${__scripter_ci+x}" ]; then return 0; fi
  __scripter_detect_forced_ci || __scripter_detect_ci_from_env
}

# Optional -v <var>.
# shellcheck disable=SC2120
ctx::ci_provider() {
  __scripter_ret_var "$@"
  __scripter_ensure_ci
  __scripter_ret "$__scripter_ret_to" "$__scripter_ci"
}

ctx::is_ci() {
  __scripter_ensure_ci
  [ -n "$__scripter_ci" ]
}

__scripter_ci_renders_color() {
  case $__scripter_ci in
    github | forgejo | gitlab | buildkite | azure | teamcity | woodpecker | drone | circleci) return 0 ;;
    *) return 1 ;;
  esac
}
