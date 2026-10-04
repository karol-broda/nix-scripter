branch=""
git::branch -v branch
ui::kv "branch" "$branch"
if ! git::is_clean; then
  ui::warn "the working tree has uncommitted changes"
fi
ui::info "preparing release ${args[version]}"
run git tag --annotate "v${args[version]}" --message "release ${args[version]}"
