ui::header "Header"
ui::section "Section"
ui::info "an info"
ui::debug "a debug"
ui::warn "a warning"
ui::error "an error"
ui::success "a success"
ui::kv key value
ui::list one two
ui::group_begin "Group"
ui::info "inside"
ui::group_end
ui::group "Command group" -- echo "from command"
ui::annotate warning "check this" src/main.c 42
ui::mask "s3cret"
printf 'a\tbb\nccc\td\n' | ui::table
ui::spin "Spinning" -- true
ui::progress 5 10 "Copying"
ui::progress 10 10 "Copying"
echo "stdout stays clean"
