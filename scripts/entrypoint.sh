#!/bin/sh
set -eu

BACKUP_CRON="${BACKUP_CRON:-0 */6 * * *}"
HEALTH_PORT="${HEALTH_PORT:-8080}"

log() { printf '{"time":"%s","level":"%s","msg":"%s"}\n' "$(date -u +%FT%TZ)" "$1" "$2"; }

log "info" "Initializing immich-backup"

# Validate required environment
for var in AZURE_ACCOUNT_NAME AZURE_ACCOUNT_KEY RESTIC_REPOSITORY RESTIC_PASSWORD PGHOST PGUSER PGPASSWORD PGDATABASE; do
    eval val="\$$var"
    if [ -z "$val" ]; then
        log "error" "Required environment variable $var is not set"
        exit 1
    fi
done

# Initialize restic repo if it doesn't exist
if ! restic snapshots --no-lock >/dev/null 2>&1; then
    log "info" "Initializing restic repository at $RESTIC_REPOSITORY"
    restic init
    log "info" "Restic repository initialized"
else
    log "info" "Restic repository already initialized"
fi

# Ensure data directory exists
mkdir -p /data

# Write crontab
cat > /tmp/crontab <<CRON
${BACKUP_CRON} /scripts/backup.sh >> /proc/1/fd/1 2>&1
0 3 * * 0 /scripts/prune.sh >> /proc/1/fd/1 2>&1
CRON
crontab /tmp/crontab
rm /tmp/crontab
log "info" "Crontab installed. Backup: ${BACKUP_CRON}. Prune: weekly Sunday 03:00"

# Set up health endpoint
mkdir -p /data/cgi-bin
cat > /data/cgi-bin/health <<'HEALTH'
#!/bin/sh
LAST_BACKUP="/data/last-backup"
if [ -f "$LAST_BACKUP" ]; then
    AGE=$(( $(date +%s) - $(date -r "$LAST_BACKUP" +%s) ))
    # Unhealthy if last backup is older than 25 hours (allows for 6h schedule + margin)
    if [ "$AGE" -gt 90000 ]; then
        printf "Status: 503 Service Unavailable\r\nContent-Type: application/json\r\n\r\n"
        printf '{"status":"unhealthy","last_backup_age_seconds":%d}\n' "$AGE"
        exit 0
    fi
    printf "Status: 200 OK\r\nContent-Type: application/json\r\n\r\n"
    printf '{"status":"healthy","last_backup_age_seconds":%d}\n' "$AGE"
else
    # No backup yet — healthy if container just started (< 7 hours)
    printf "Status: 200 OK\r\nContent-Type: application/json\r\n\r\n"
    printf '{"status":"healthy","last_backup":"never"}\n'
fi
HEALTH
chmod +x /data/cgi-bin/health

# Start health endpoint in background
httpd -f -p "$HEALTH_PORT" -h /data &
log "info" "Health endpoint listening on port $HEALTH_PORT"

# Run initial backup on first start if no previous backup exists
if [ ! -f /data/last-backup ]; then
    log "info" "No previous backup found. Running initial backup"
    /scripts/backup.sh || log "warn" "Initial backup failed — will retry on next cron cycle"
fi

# Start cron in foreground
log "info" "Starting cron daemon"
exec crond -f -l 6
