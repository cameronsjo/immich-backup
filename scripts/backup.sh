#!/bin/sh
set -eu

log() { printf '{"time":"%s","level":"%s","msg":"%s"}\n' "$(date -u +%FT%TZ)" "$1" "$2"; }

DUMP_FILE="/data/immich.sql"
START_TIME=$(date +%s)

log "info" "Starting Immich backup"

# Step 1: Database dump
log "info" "Dumping PostgreSQL database $PGDATABASE from $PGHOST"
if pg_dump --clean --if-exists --no-owner --no-privileges -f "$DUMP_FILE"; then
    DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
    log "info" "Database dump complete. Size: $DUMP_SIZE"
else
    log "error" "pg_dump failed"
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
        curl -sf -H "Content-Type: application/json" \
            -d "{\"content\":\"**Immich Backup Failed**\\npg_dump error at $(date -u +%FT%TZ)\"}" \
            "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
    exit 1
fi

# Step 2: Restic backup (DB dump + photo originals)
log "info" "Starting restic backup of database dump and photo library"
RESTIC_OUTPUT=$(restic backup \
    "$DUMP_FILE" \
    /photos \
    --exclude="thumbs/**" \
    --exclude="encoded-video/**" \
    --tag immich \
    --tag "$(date -u +%F)" \
    --json 2>&1 | tail -1)

if [ $? -eq 0 ]; then
    SNAPSHOT_ID=$(echo "$RESTIC_OUTPUT" | jq -r '.snapshot_short_id // "unknown"')
    FILES_NEW=$(echo "$RESTIC_OUTPUT" | jq -r '.files_new // 0')
    FILES_CHANGED=$(echo "$RESTIC_OUTPUT" | jq -r '.files_changed // 0')
    DATA_ADDED=$(echo "$RESTIC_OUTPUT" | jq -r '.data_added // 0')
    DATA_ADDED_HR=$(echo "$DATA_ADDED" | awk '{
        if ($1 > 1073741824) printf "%.1f GB", $1/1073741824
        else if ($1 > 1048576) printf "%.1f MB", $1/1048576
        else if ($1 > 1024) printf "%.1f KB", $1/1024
        else printf "%d B", $1
    }')

    DURATION=$(( $(date +%s) - START_TIME ))
    log "info" "Restic backup complete. Snapshot: $SNAPSHOT_ID. New: $FILES_NEW. Changed: $FILES_CHANGED. Added: $DATA_ADDED_HR. Duration: ${DURATION}s"

    # Update last-backup marker
    date -u +%FT%TZ > /data/last-backup

    # Discord success notification
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
        curl -sf -H "Content-Type: application/json" \
            -d "{\"embeds\":[{\"title\":\"Immich Backup Complete\",\"color\":3066993,\"fields\":[{\"name\":\"Snapshot\",\"value\":\"$SNAPSHOT_ID\",\"inline\":true},{\"name\":\"Duration\",\"value\":\"${DURATION}s\",\"inline\":true},{\"name\":\"New files\",\"value\":\"$FILES_NEW\",\"inline\":true},{\"name\":\"Changed\",\"value\":\"$FILES_CHANGED\",\"inline\":true},{\"name\":\"Data added\",\"value\":\"$DATA_ADDED_HR\",\"inline\":true},{\"name\":\"DB dump\",\"value\":\"$DUMP_SIZE\",\"inline\":true}]}]}" \
            "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
else
    log "error" "Restic backup failed"
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
        curl -sf -H "Content-Type: application/json" \
            -d "{\"content\":\"**Immich Backup Failed**\\nRestic error at $(date -u +%FT%TZ)\"}" \
            "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
    exit 1
fi
