{
  runCommand,
  jq,
  findutils,
  backup,
}:
runCommand "backup-roundtrip"
  {
    nativeBuildInputs = [
      backup
      jq
      findutils
    ];
  }
  ''
    set -euo pipefail
    export HOME=$TMPDIR XDG_CACHE_HOME=$TMPDIR/cache
    export RESTIC_REPOSITORY=$TMPDIR/repo RESTIC_PASSWORD_FILE=$TMPDIR/password
    echo correct-horse > "$RESTIC_PASSWORD_FILE"

    mkdir -p data/nested
    echo "important" > data/nested/file.txt

    backup init
    backup run data --tag nightly
    [ "$(backup list --json | jq length)" -eq 1 ]
    [ "$(backup list --tag nightly --json | jq -r '.[0].tags[0]')" = nightly ]

    backup restore --target restored
    restored=$(find restored -path '*/data/nested/file.txt')
    [ "$(cat "$restored")" = important ]

    backup --dry-run prune 2> dry-run.txt
    grep -q "would run: restic forget --prune" dry-run.txt
    backup --yes prune --keep-daily 1
    touch $out
  ''
