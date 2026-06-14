#!/bin/sh
set -eu

log() { printf '{"time":"%s","level":"%s","msg":"%s"}\n' "$(date -u +%FT%TZ)" "$1" "$2"; }

# Defaults preserve the original Immich behavior byte-for-byte.
BACKUP_NAME="${BACKUP_NAME:-Immich}"

log "info" "Starting restic prune"

BEFORE=$(restic snapshots --json 2>/dev/null | jq 'length')

restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --prune \
    --tag "${BACKUP_TAG:-immich}"

AFTER=$(restic snapshots --json 2>/dev/null | jq 'length')
REMOVED=$(( BEFORE - AFTER ))

log "info" "Prune complete. Removed: $REMOVED snapshots. Remaining: $AFTER"

if [ -n "${DISCORD_WEBHOOK_URL:-}" ] && [ "$REMOVED" -gt 0 ]; then
    curl -sf -H "Content-Type: application/json" \
        -d "{\"content\":\"**$BACKUP_NAME Backup Pruned** — removed $REMOVED snapshots, $AFTER remaining\"}" \
        "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
fi
