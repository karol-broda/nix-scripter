git::branch() {
  __scripter_ret_var "$@"
  __scripter_ret "$__scripter_ret_to" "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
}

git::is_clean() {
  [ -z "$(git status --porcelain 2>/dev/null)" ]
}

git::remote_url() {
  __scripter_ret_var "$@"
  __scripter_ret "$__scripter_ret_to" "$(git remote get-url "$__example_git_remote" 2>/dev/null || true)"
}

# git::changed_files -v <array>
git::changed_files() {
  if [ "${1:-}" != -v ] || [ -z "${2:-}" ]; then
    die "usage: git::changed_files -v <array>"
  fi
  local -n __example_files=$2
  local __example_file
  __example_files=()
  while IFS= read -r __example_file; do
    __example_files+=("$__example_file")
  done < <(git diff --name-only 2>/dev/null)
}
