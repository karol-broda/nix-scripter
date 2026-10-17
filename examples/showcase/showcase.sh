case ${args[as]} in
  terminal) export SCRIPTER_UI=fancy ;;
  plain) export SCRIPTER_UI=plain ;;
  github | gitlab) export SCRIPTER_CI=${args[as]} ;;
esac
if [[ -n ${args[icons]} ]]; then
  export SCRIPTER_ICONS=${args[icons]}
fi

pause() {
  sleep "${args[delay]}"
}

failing_step() {
  echo "error: the compiler says no" >&2
  return 3
}

colors=off
if ctx::color; then colors=on; fi

ui::header "nix-scripter showcase"
ui::info "everything below is the ui feature, rendered for $(ctx::renderer)"

ui::section "Messages"
ui::debug "debug: only shown with --verbose"
ui::info "info: something happened"
ui::success "success: it worked"
ui::warn "warning: worth a look"
ui::error "error: something failed (the showcase carries on)"

ui::section "Key/value pairs and lists"
ui::kv "renderer" "$(ctx::renderer)"
ui::kv "platform" "$(ctx::os)/$(ctx::arch)"
ui::kv "colors" "$colors"
ui::list "lists use the icon set's bullet" "second item" "third item"

ui::section "Tables"
printf 'package\tversion\tsize\nbash\t5.3\t9.1 MiB\njq\t1.8.2\t1.2 MiB\ncurl\t8.22.0\t4.4 MiB\n' | ui::table

ui::section "Progress"
for ((step = 0; step <= 20; step++)); do
  ui::progress "$step" 20 "Downloading"
  pause
done

ui::section "Spinners"
ui::spin "Resolving dependencies" -- sleep 1
ui::spin "Building" -- sleep 1.5
ui::spin "A failing step shows its output" -- failing_step || true

ui::group_begin "Groups (collapsible in CI logs)"
ui::info "inside a group"
ui::group_begin "Nested group"
ui::info "nested groups indent in a terminal"
ui::group_end
ui::group_end

ui::section "CI integration"
ui::annotate warning "annotations point at a file and line in CI" showcase.sh 42
ui::mask "hunter2"
ui::info "masked values never appear in CI logs"

ui::section "Prompts"
if ctx::is_interactive; then
  flavour="" name=""
  ui::choose -v flavour --default chocolate "Pick a flavour (arrow keys)" vanilla chocolate strawberry
  ui::prompt -v name "What's your name?" "${USER:-friend}"
  if ui::confirm "Print a greeting?" y; then
    ui::success "enjoy your $flavour, $name"
  fi
else
  ui::info "prompts need a terminal; run the showcase interactively to try them"
fi
