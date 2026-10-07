export RESTIC_REPOSITORY=${args[repo]}
export RESTIC_PASSWORD_FILE=${args[password_file]}

# restic's output is only shown when it fails.
restic_step() {
  local message=$1
  shift
  if is_true "${SCRIPTER_DRY_RUN:-}"; then
    run restic "$@"
  else
    ui::spin "$message" -- restic --quiet "$@"
  fi
}

confirm_destructive() {
  is_true "${SCRIPTER_DRY_RUN:-}" || ui::confirm "$1" n || die "$2"
}

snapshots_json() {
  local -a filters=()
  local tag
  for tag in "${args_tag[@]+"${args_tag[@]}"}"; do
    filters+=(--tag "$tag")
  done
  restic snapshots --json "${filters[@]+"${filters[@]}"}"
}

cmd::init() {
  restic_step "Creating repository $RESTIC_REPOSITORY" init
}

cmd::run() {
  local -a paths=("${args_paths[@]+"${args_paths[@]}"}") options=()
  local tag snapshot
  if [ "${#paths[@]}" -eq 0 ]; then
    paths=("$HOME")
  fi
  for tag in "${args_tag[@]+"${args_tag[@]}"}"; do
    options+=(--tag "$tag")
  done
  if [[ -n ${args[one_file_system]} ]]; then
    options+=(--one-file-system)
  fi

  ui::header "Backing up to $RESTIC_REPOSITORY"
  ui::list "${paths[@]}"
  restic_step "Uploading" backup "${options[@]+"${options[@]}"}" "${paths[@]}"
  if is_true "${SCRIPTER_DRY_RUN:-}"; then
    return 0
  fi

  snapshot=$(restic snapshots --json --latest 1 | jq -r 'last | .short_id')
  ui::kv "snapshot" "$snapshot"
  {
    printf '### Backup %s\n\n' "$snapshot"
    printf -- '- %s\n' "${paths[@]}"
  } | ui::summary
}

cmd::list() {
  if [[ -n ${args[json]} ]]; then
    snapshots_json
    return 0
  fi
  snapshots_json | jq -r '
    ["id", "time", "host", "tags", "paths"],
    (.[] | [.short_id, (.time[:19] | sub("T"; " ")), .hostname,
            ((.tags // []) | join(",")), (.paths | join(", "))])
    | @tsv' | ui::table
}

cmd::restore() {
  local target=${args[target]}
  if [ -d "$target" ] && [ -n "$(ls -A "$target")" ]; then
    confirm_destructive "$target is not empty, restore into it anyway?" "restore cancelled"
  fi
  restic_step "Restoring ${args[snapshot]} into $target" restore "${args[snapshot]}" --target "$target"
}

cmd::prune() {
  ui::header "Retention policy"
  ui::kv "daily" "${args[keep_daily]}"
  ui::kv "weekly" "${args[keep_weekly]}"
  ui::kv "monthly" "${args[keep_monthly]}"
  confirm_destructive "Forget older snapshots and delete their data?" "prune cancelled"
  restic_step "Pruning" forget --prune \
    --keep-daily "${args[keep_daily]}" \
    --keep-weekly "${args[keep_weekly]}" \
    --keep-monthly "${args[keep_monthly]}"
}
