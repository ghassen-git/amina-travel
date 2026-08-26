# Amina Travel — Production Scripts

This directory contains operational scripts for the production environment.

---

## Available Scripts

### backup-postgres.sh

**Purpose:** Daily automated PostgreSQL backup to Cloudflare R2

**What it does:**
- Dumps PostgreSQL database
- Compresses with gzip
- Encrypts with AES-256-CBC
- Uploads to Cloudflare R2
- Cleans up old backups (30-day retention)

**Usage:**
```bash
# Normal execution (run manually or via systemd timer)
cd /opt/amina-travel/deploy
source .env
./scripts/backup-postgres.sh

# Dry run (test mode)
DRY_RUN=1 ./scripts/backup-postgres.sh
```

**Requirements:**
- Docker installed and running
- `amina-postgres` container running
- AWS CLI installed
- Environment variables configured in `/opt/amina-travel/deploy/.env`

**Exit codes:**
- `0` = Success
- `1` = Validation failure (missing env vars, container not running)
- `2` = Backup creation failure
- `3` = Upload failure
- `4` = Retention cleanup failure

**Automated execution:**
- Via systemd timer: `/etc/systemd/system/amina-postgres-backup.timer`
- Runs daily at 02:00 server time
- Logs to journald: `journalctl -u amina-postgres-backup.service`

**Documentation:**
- See [PRODUCTION_BACKUP.md](../../docs/PRODUCTION_BACKUP.md)

---

## Adding New Scripts

When adding operational scripts:

1. **Make executable:** `chmod +x scripts/your-script.sh`
2. **Use strict mode:** `set -euo pipefail` at the top
3. **Add logging:** Include timestamps and clear error messages
4. **Document here:** Update this README
5. **Add to deployment guide:** Reference in PRODUCTION_DEPLOYMENT_STEPS.md

---

## Directory Structure

```
deploy/
├── scripts/
│   ├── backup-postgres.sh       # PostgreSQL backup script
│   └── README.md                # This file
├── systemd/
│   ├── amina-postgres-backup.service
│   └── amina-postgres-backup.timer
├── nginx/
│   └── templates/
│       └── amina.conf.template
├── docker-compose.prod.yml
├── .env                         # Production secrets (not in Git)
├── .env.production.example      # Template
└── PRODUCTION_DEPLOYMENT_STEPS.md
```

---

## Security Notes

- All scripts source environment variables from `/opt/amina-travel/deploy/.env`
- Secrets are never printed in logs
- Temporary files are deleted immediately after use
- Scripts run as root (required for Docker access)
- Backup files are encrypted before upload

---

## Troubleshooting

### Script won't execute

```bash
# Check permissions
ls -la /opt/amina-travel/deploy/scripts/

# If not executable
chmod +x /opt/amina-travel/deploy/scripts/*.sh
```

### Environment variables not loading

```bash
# Verify .env exists
ls -la /opt/amina-travel/deploy/.env

# Check permissions
chmod 600 /opt/amina-travel/deploy/.env

# Test sourcing
cd /opt/amina-travel/deploy
source .env
echo $R2_BUCKET
```

### View script execution logs

```bash
# For systemd-managed scripts
journalctl -u amina-postgres-backup.service -n 100

# For manual runs
# Check script output (scripts log to stdout/stderr)
```

---

## Related Documentation

- [PRODUCTION_BACKUP.md](../../docs/PRODUCTION_BACKUP.md) — Backup system documentation
- [PRODUCTION_SERVER_HARDENING.md](../../docs/PRODUCTION_SERVER_HARDENING.md) — Server hardening guide
- [PRODUCTION_DEPLOYMENT_STEPS.md](../PRODUCTION_DEPLOYMENT_STEPS.md) — Deployment checklist
