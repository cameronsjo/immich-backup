# immich-backup

Encrypted backup sidecar for [Immich](https://immich.app) — dumps PostgreSQL and backs up photo originals to Azure Blob Storage via [restic](https://restic.net).

## What It Does

- **pg_dump** the Immich database every 6 hours
- **restic backup** the DB dump + photo originals to Azure Blob Storage
- **Prune** old snapshots weekly (7 daily, 4 weekly, 6 monthly)
- **Discord** notifications on success/failure
- **Health endpoint** at `/cgi-bin/health` for orchestrator checks

## What It Doesn't Back Up

Thumbnails and transcoded previews are regenerable from originals and are excluded to save storage costs.

## Environment Variables

| Variable | Required | Description |
|----------|:--------:|-------------|
| `AZURE_ACCOUNT_NAME` | Yes | Azure Storage account name |
| `AZURE_ACCOUNT_KEY` | Yes | Azure Storage account key |
| `RESTIC_REPOSITORY` | Yes | Restic repo URI (e.g., `azure:immich-backup:/backup`) |
| `RESTIC_PASSWORD` | Yes | Restic encryption password |
| `PGHOST` | Yes | PostgreSQL hostname |
| `PGPORT` | No | PostgreSQL port (default: `5432`) |
| `PGUSER` | Yes | PostgreSQL username |
| `PGPASSWORD` | Yes | PostgreSQL password |
| `PGDATABASE` | Yes | PostgreSQL database name |
| `DISCORD_WEBHOOK_URL` | No | Discord webhook for notifications |
| `BACKUP_CRON` | No | Cron schedule (default: `0 */6 * * *`) |
| `TZ` | No | Timezone (default: `UTC`) |

## Volumes

| Mount | Description |
|-------|-------------|
| `/photos` | Immich photo library (mount as read-only) |
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
