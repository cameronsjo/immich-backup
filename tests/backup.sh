#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/bin" "$tmpdir/data" "$tmpdir/photos"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/bin/restic" <<'EOF'
#!/bin/sh
printf '%s\n' '{"files_new":2,"files_changed":1,"data_added":2048,"snapshot_id":"9ab85bbbbffc86eb64255435602ff7a7422471a1b0443c09ecb4d9160144ae89"}'
EOF
chmod +x "$tmpdir/bin/restic"

output=$(PATH="$tmpdir/bin:$PATH" \
    BACKUP_PATHS="$tmpdir/photos" \
    BACKUP_EXCLUDES='' \
    DATA_DIR="$tmpdir/data" \
    BACKUP_TAG=test \
    BACKUP_NAME=Test \
    /bin/sh "$repo_root/scripts/backup.sh" 2>&1)

printf '%s\n' "$output" | grep -F 'Snapshot: 9ab85bbb.' >/dev/null
