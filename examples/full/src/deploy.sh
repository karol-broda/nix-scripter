render_manifest() {
  local dir=$1
  jq -n \
    --arg app "${args[app]}" \
    --arg env "${args[env]}" \
    --arg version "${args[release]}" \
    --argjson replicas "${args[replicas]}" \
    --args '{ app: $app, env: $env, version: $version, replicas: $replicas, labels: $ARGS.positional }' \
    "${args_label[@]+"${args_label[@]}"}" >"$dir/manifest.json"
  ui::info "wrote $dir/manifest.json"
}

roll_out() {
  local replica
  for ((replica = 1; replica <= args[replicas]; replica++)); do
    ui::progress "$replica" "${args[replicas]}" "Rolling out ${args[app]}"
    sleep 0.2
  done
}

ui::header "Deploying ${args[app]} ${args[release]} to ${args[env]}"
ui::kv "services" "${args_services[*]:-all}"
ui::kv "replicas" "${args[replicas]}"
ui::kv "labels" "${args_label[*]:-none}"
ui::kv "renderer" "$(ctx::renderer)"

if [[ ${args[env]} == prod && -z ${args[force]} ]]; then
  ui::confirm "Deploy to production?" n || die "aborted" 1
fi

if [[ -n ${DEPLOY_TOKEN:-} ]]; then
  ui::mask "$DEPLOY_TOKEN"
fi

workdir=""
mktemp_dir -v workdir
on_exit ui::debug "removing $workdir"

ui::group "Render manifest" -- render_manifest "$workdir"
ui::spin "Uploading artifacts" -- sleep 1
run touch "$workdir/uploaded"

if [[ -n ${args[canary]} ]]; then
  ui::warn "canary rollout: ${args[canary]} of traffic"
  ui::annotate warning "canary deployment of ${args[app]}" deploy.sh
fi

if [[ -n ${args[wait]} ]]; then
  roll_out
fi

printf '### Deployed %s\n\n| key | value |\n|---|---|\n| env | %s |\n| version | %s |\n' \
  "${args[app]}" "${args[env]}" "${args[release]}" | ui::summary

ui::success "deployed ${args[app]} to ${args[env]}"
