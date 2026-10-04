cmd::publish() {
  local remote
  git::remote_url -v remote
  ui::section "Publishing to ${remote:-<no remote>}"
  if [[ -n ${args[draft]} ]]; then
    ui::info "as a draft"
  fi
  run git push --tags "${remote:-origin}"
}

cmd::notes::show() {
  local -a changed
  git::changed_files -v changed
  ui::header "Release notes"
  ui::list "${changed[@]:-no changes}"
}

ui::debug "release tooling on $(ctx::os)/$(ctx::arch)"
