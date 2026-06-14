# immich-backup

Encrypted backup sidecar — backs up files (and optionally a PostgreSQL dump) to Azure Blob Storage via [restic](https://restic.net). Ships with [Immich](https://immich.app) defaults out of the box, but generalizes to any file-set: point `BACKUP_PATHS` at the directories you want and leave `PGHOST` unset to run a files-only instance.

## What It Does

- **pg_dump** the database every cycle — skipped entirely when `PGHOST` is unset
- **restic backup** the DB dump (if any) + the configured source paths to Azure Blob Storage
- **Prune** old snapshots weekly (7 daily, 4 weekly, 6 monthly)
- **Discord** notifications on success/failure
- **Health endpoint** at `/cgi-bin/health` for orchestrator checks

## What It Doesn't Back Up

`BACKUP_EXCLUDES` is a space-separated list of restic patterns to skip. The Immich default (`thumbs/** encoded-video/**`) drops regenerable thumbnails and transcoded previews to save storage. Set it to an empty string to exclude nothing.

## Environment Variables

| Variable | Required | Description |
|----------|:--------:|-------------|
| `AZURE_ACCOUNT_NAME` | Yes | Azure Storage account name |
| `AZURE_ACCOUNT_KEY` | Yes | Azure Storage account key |
| `RESTIC_REPOSITORY` | Yes | Restic repo URI (e.g., `azure:immich-backup:/backup`) |
| `RESTIC_PASSWORD` | Yes | Restic encryption password |
| `BACKUP_PATHS` | No | Space-separated source paths (default: `/photos`) |
| `BACKUP_EXCLUDES` | No | Space-separated restic exclude patterns (default: `thumbs/** encoded-video/**`; empty = none) |
| `BACKUP_NAME` | No | Label used in logs and Discord notifications (default: `Immich`) |
| `BACKUP_TAG` | No | restic snapshot tag, also used for prune retention (default: `immich`) |
| `PGHOST` | If DB | PostgreSQL hostname — set to enable the DB dump; unset for files-only |
| `PGPORT` | No | PostgreSQL port (default: `5432`) |
| `PGUSER` | If DB | PostgreSQL username (required when `PGHOST` is set) |
| `PGPASSWORD` | If DB | PostgreSQL password (required when `PGHOST` is set) |
| `PGDATABASE` | If DB | PostgreSQL database name (required when `PGHOST` is set) |
| `DISCORD_WEBHOOK_URL` | No | Discord webhook for notifications |
| `BACKUP_CRON` | No | Cron schedule (default: `0 */6 * * *`) |
| `TZ` | No | Timezone (default: `UTC`) |

## Volumes

| Mount | Description |
|-------|-------------|
| `/photos` | Immich photo library (default `BACKUP_PATHS`; mount as read-only). Files-only instances mount their own source paths instead. |
| `/data` | Working directory for DB dumps and state |

## Verification

```bash
# Check last backup
docker exec immich-backup cat /data/last-backup

# List snapshots
docker exec immich-backup restic snapshots

# Manual backup
docker exec immich-backup /scripts/backup.sh

# Restore (to a temp directory)
docker exec immich-backup restic restore latest --target /tmp/restore
```

## Supply Chain Security

Images are signed with [Cosign](https://docs.sigstore.dev/cosign/overview/) and include SLSA build provenance attestations.

```bash
# Verify signature
cosign verify ghcr.io/cameronsjo/immich-backup:latest

# Verify provenance
gh attestation verify oci://ghcr.io/cameronsjo/immich-backup:latest -R cameronsjo/immich-backup
```

## License

MIT
