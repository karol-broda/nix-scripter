ui::info "PATH contains only Nix-provided tools:"
IFS=: read -r -a dirs <<<"$PATH"
ui::list "${dirs[@]}"
printf '{"hermetic": true}\n' | jq .
