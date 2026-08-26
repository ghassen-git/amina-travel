# Amina Travel — Production Backup System

Complete documentation for the PostgreSQL backup system with Cloudflare R2.

---

## Architecture Overview

```
PostgreSQL Container (amina-postgres)
         ↓
    pg_dump (SQL format)
         ↓
    gzip compression
         ↓
    openssl AES-256-CBC encryption
         ↓
    Cloudflare R2 (S3-compatible)
         ↓
    30-day retention (automatic cleanup)
```

**Key Design Decisions:**

- Backup runs **independently from application containers** via systemd timer
- Host-level script prevents deployment from breaking backups
- Encryption-at-rest before upload (zero-knowledge backup)
- Temporary files deleted immediately after upload
- No permanent on-VPS backup storage (prevents disk fill)

---

## Environment Variables

All configuration lives in `/opt/amina-travel/deploy/.env`:

```bash
# Cloudflare R2 Configuration
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_BUCKET=amina-travel-backups
R2_ACCESS_KEY_ID=<r2-access-key-id>
R2_SECRET_ACCESS_KEY=<r2-secret-access-key>

# Backup Encryption Key (MUST be ≥32 characters)
BACKUP_ENCRYPTION_KEY=<long-random-string-minimum-32-characters>

# PostgreSQL Connection (already exists)
POSTGRES_USER=amina
POSTGRES_PASSWORD=<existing-db-password>
POSTGRES_DB=amina_travel
```

### Obtaining R2 Credentials

1. Log in to Cloudflare dashboard
2. Navigate to **R2 Object Storage**
3. Create a bucket: `amina-travel-backups`
4. Go to **Manage R2 API Tokens**
5. Create a new API token with:
   - **Permissions:** Object Read & Write
   - **Bucket:** `amina-travel-backups` (specific bucket)
6. Copy the generated:
   - Access Key ID → `R2_ACCESS_KEY_ID`
   - Secret Access Key → `R2_SECRET_ACCESS_KEY`
   - Endpoint URL → `R2_ENDPOINT` (format: `https://<account-id>.r2.cloudflarestorage.com`)

### Generating the Encryption Key

**CRITICAL:** This key encrypts all backups. If lost, backups become unrecoverable.

Generate a strong key:

```bash
openssl rand -base64 48
```

Copy the output to `BACKUP_ENCRYPTION_KEY` in `.env`.

**Backup the encryption key separately:**

1. Store in a password manager (1Password, LastPass, Bitwarden)
2. Print to paper and store in a physical safe
3. Store in a secure note in company documentation
4. **DO NOT** commit to Git
5. **DO NOT** store only on the production server

---

## Installation

### 1. Install AWS CLI

The backup script uses AWS CLI for S3-compatible R2 access:

```bash
apt-get update
apt-get install -y awscli

# Verify installation
aws --version
```

### 2. Deploy Backup Script

Copy the backup script to the production server:

```bash
# On production server
cd /opt/amina-travel/deploy
chmod +x scripts/backup-postgres.sh
```

### 3. Configure Environment Variables

Edit `/opt/amina-travel/deploy/.env`:

```bash
nano /opt/amina-travel/deploy/.env
```

Add the R2 and encryption configuration variables shown above.

### 4. Test Backup Manually

Run a dry-run test:

```bash
cd /opt/amina-travel/deploy
source .env
DRY_RUN=1 ./scripts/backup-postgres.sh
```

Run an actual backup:

```bash
cd /opt/amina-travel/deploy
source .env
./scripts/backup-postgres.sh
```

Check the logs for success. Verify the backup appears in R2.

### 5. Install Systemd Service & Timer

```bash
# Copy systemd files
cp /opt/amina-travel/deploy/systemd/amina-postgres-backup.service /etc/systemd/system/
cp /opt/amina-travel/deploy/systemd/amina-postgres-backup.timer /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable and start the timer
systemctl enable amina-postgres-backup.timer
systemctl start amina-postgres-backup.timer

# Verify the timer is active
systemctl status amina-postgres-backup.timer
systemctl list-timers --all | grep amina
```

---

## Scheduling

The backup runs **daily at 02:00 server local time** via systemd timer.

**Timer Features:**

- **Persistent:** If the server was off at 02:00, the backup runs shortly after boot
- **Randomized:** Start time randomized by up to 10 minutes to avoid exact-time spikes
- **Logged:** All output goes to journald

### Verify Timer Status

```bash
# Check timer status
systemctl status amina-postgres-backup.timer

# List all timers
systemctl list-timers --all

# View next scheduled run
systemctl list-timers | grep amina
```

### View Backup Logs

```bash
# View recent backup logs
journalctl -u amina-postgres-backup.service -n 100

# Follow live logs
journalctl -u amina-postgres-backup.service -f

# View logs for a specific date
journalctl -u amina-postgres-backup.service --since "2026-08-25"
```

### Manual Backup

Trigger a manual backup without waiting for the timer:

```bash
systemctl start amina-postgres-backup.service
```

Watch it run:

```bash
journalctl -u amina-postgres-backup.service -f
```

---

## Backup Verification

**A backup is NOT considered successful merely because pg_dump succeeded.**

The backup script performs these verifications:

1. **Container running:** Verifies `amina-postgres` container is up
2. **Dump size:** Rejects dumps smaller than 1 KB (likely incomplete)
3. **Compression success:** Verifies gzip completed
4. **Encryption success:** Verifies openssl completed
5. **Upload success:** Verifies AWS CLI upload succeeded
6. **Remote existence:** Verifies the file exists in R2 after upload

### Monthly Restore Test

**CRITICAL:** Test restores monthly to ensure backups are actually recoverable.

```bash
# Set reminder
echo "0 10 1 * * /opt/amina-travel/deploy/scripts/test-restore.sh" | crontab -
```

See **Restore Procedure** below for test restore steps.

---

## Listing Backups

### Via AWS CLI

```bash
# Load R2 credentials
source /opt/amina-travel/deploy/.env

# List all backups
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 ls s3://${R2_BUCKET}/backups/ \
  --endpoint-url "${R2_ENDPOINT}" \
  --recursive \
  --human-readable

# List backups from last 7 days
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 ls s3://${R2_BUCKET}/backups/ \
  --endpoint-url "${R2_ENDPOINT}" \
  --recursive | grep "$(date -d '7 days ago' +%Y-%m)"
```

### Via Cloudflare Dashboard

1. Log in to Cloudflare dashboard
2. Navigate to **R2 Object Storage**
3. Click on the `amina-travel-backups` bucket
4. Browse the `backups/` folder

---

## Restore Procedure

### ⚠️ CRITICAL WARNING

**RESTORING TO PRODUCTION WILL OVERWRITE THE CURRENT DATABASE.**

**For your first restore test, ALWAYS restore to a temporary test database.**

---

### Test Restore (Recommended First Step)

This creates a new test database without touching production:

```bash
# 1. Download and decrypt a backup
source /opt/amina-travel/deploy/.env
RESTORE_DATE="2026-08-26_020000"  # Example: adjust to actual backup filename

# Download from R2
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 cp \
  "s3://${R2_BUCKET}/backups/amina_travel_${RESTORE_DATE}.sql.gz.enc" \
  "/tmp/restore.sql.gz.enc" \
  --endpoint-url "${R2_ENDPOINT}"

# Decrypt
openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
  -in /tmp/restore.sql.gz.enc \
  -out /tmp/restore.sql.gz \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}"

# Decompress
gunzip /tmp/restore.sql.gz

# 2. Create a test database
docker exec amina-postgres psql -U amina -c "CREATE DATABASE amina_travel_test;"

# 3. Restore to test database
docker exec -i amina-postgres psql -U amina -d amina_travel_test < /tmp/restore.sql

# 4. Verify critical tables exist
docker exec amina-postgres psql -U amina -d amina_travel_test -c "
  SELECT schemaname, tablename 
  FROM pg_tables 
  WHERE schemaname IN ('hotels', 'bookings', 'payments', 'auth')
  ORDER BY schemaname, tablename;
"

# 5. Verify data counts
docker exec amina-postgres psql -U amina -d amina_travel_test -c "
  SELECT 'hotels.hotels' AS table_name, COUNT(*) FROM hotels.hotels
  UNION ALL
  SELECT 'bookings.bookings', COUNT(*) FROM bookings.bookings
  UNION ALL
  SELECT 'payments.payments', COUNT(*) FROM payments.payments
  UNION ALL
  SELECT 'auth.refresh_tokens', COUNT(*) FROM auth.refresh_tokens;
"

# 6. Clean up test database
docker exec amina-postgres psql -U amina -c "DROP DATABASE amina_travel_test;"
rm -f /tmp/restore.sql /tmp/restore.sql.gz /tmp/restore.sql.gz.enc
```

---

### Production Restore (DANGEROUS)

**Only proceed if you understand you are overwriting the live database.**

**Prerequisites:**

1. ✅ You have tested restore to a test database (above)
2. ✅ You have confirmed with stakeholders that production restore is authorized
3. ✅ You have stopped the application containers to prevent writes during restore
4. ✅ You have taken a final snapshot of the current (about-to-be-replaced) database

```bash
# STOP THE APPLICATION
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml stop api web admin

# FINAL SAFETY BACKUP (before you destroy current state)
docker exec amina-postgres pg_dump -U amina amina_travel | gzip > /tmp/final-backup-before-restore-$(date +%Y%m%d-%H%M%S).sql.gz

# Download and decrypt the backup (same as test restore)
source /opt/amina-travel/deploy/.env
RESTORE_DATE="2026-08-26_020000"  # Adjust to actual backup

AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 cp \
  "s3://${R2_BUCKET}/backups/amina_travel_${RESTORE_DATE}.sql.gz.enc" \
  "/tmp/restore-prod.sql.gz.enc" \
  --endpoint-url "${R2_ENDPOINT}"

openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
  -in /tmp/restore-prod.sql.gz.enc \
  -out /tmp/restore-prod.sql.gz \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}"

gunzip /tmp/restore-prod.sql.gz

# DROP AND RECREATE THE PRODUCTION DATABASE
docker exec amina-postgres psql -U amina -c "DROP DATABASE amina_travel;"
docker exec amina-postgres psql -U amina -c "CREATE DATABASE amina_travel;"

# RESTORE
docker exec -i amina-postgres psql -U amina -d amina_travel < /tmp/restore-prod.sql

# VERIFY
docker exec amina-postgres psql -U amina -d amina_travel -c "
  SELECT schemaname, tablename 
  FROM pg_tables 
  WHERE schemaname IN ('hotels', 'bookings', 'payments', 'auth')
  ORDER BY schemaname, tablename;
"

# RESTART THE APPLICATION
docker compose -f docker-compose.prod.yml start api web admin
docker compose -f docker-compose.prod.yml restart nginx

# VERIFY APPLICATION HEALTH
sleep 5
curl -s http://localhost/health

# CLEAN UP
rm -f /tmp/restore-prod.sql /tmp/restore-prod.sql.gz.enc
```

---

## Retention Policy

- **Retention period:** 30 days
- **Automatic deletion:** Backups older than 30 days are deleted during each backup run
- **Storage cost:** ~30 daily backups (compressed + encrypted) typically < 10 GB total

### Adjusting Retention

Edit the backup script:

```bash
nano /opt/amina-travel/deploy/scripts/backup-postgres.sh
```

Change:

```bash
RETENTION_DAYS=30
```

To your desired retention period (e.g., `60` for 60 days).

---

## Encryption Key Handling

### Key Rotation

To rotate the encryption key:

1. Generate a new key: `openssl rand -base64 48`
2. **DO NOT** update `.env` yet
3. Download and decrypt all existing backups with the old key
4. Re-encrypt them with the new key (or accept that old backups become unrecoverable)
5. Update `BACKUP_ENCRYPTION_KEY` in `.env`
6. New backups will use the new key

**Recommendation:** Key rotation is complex. Only rotate if the key has been compromised.

### Key Recovery

If the encryption key is lost:

- ❌ **All backups are permanently unrecoverable**
- ✅ The current live database is unaffected
- ✅ Generate a new key and continue with new backups

**This is why the key must be backed up separately from the server.**

---

## Important Tables Reference

For restore verification, these are the critical schemas and tables:

| Schema | Key Tables | Purpose |
|--------|------------|---------|
| `hotels` | `hotels`, `rooms`, `hotel_images` | Hotel catalog |
| `bookings` | `bookings`, `booking_rooms` | Customer bookings |
| `payments` | `payments`, `payment_transactions` | Payment records |
| `auth` | `users`, `refresh_tokens` | User accounts & sessions |
| `promos` | `promotions`, `promo_codes` | Promotional offers |
| `voyages` | `voyages`, `voyage_itineraries` | Package tours |
| `reservations` | `reservations` | Voyage reservations |

Verify these exist after any restore.

---

## Troubleshooting

### Backup Fails: "Container not running"

```bash
# Check container status
docker ps -a | grep postgres

# If stopped, start it
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml start postgres
```

### Backup Fails: "AWS CLI not found"

```bash
apt-get install -y awscli
aws --version
```

### Backup Fails: "Upload failed"

Check R2 credentials:

```bash
source /opt/amina-travel/deploy/.env
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 ls "s3://${R2_BUCKET}/" --endpoint-url "${R2_ENDPOINT}"
```

If this fails, the R2 credentials are invalid. Regenerate them in Cloudflare dashboard.

### Restore Fails: "Decryption failed"

The `BACKUP_ENCRYPTION_KEY` is incorrect. Verify:

1. You're using the correct key from when the backup was created
2. The key hasn't been truncated (should be ≥32 characters)
3. No extra spaces or newlines in the key

### Disk Full

Backups should never fill the disk because:

1. Temporary files are deleted immediately after upload
2. No permanent on-VPS backup storage

If disk is full:

```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Clean up old backups (if any exist locally)
rm -rf /opt/amina-travel/backups/tmp/*
```

---

## Security Considerations

1. **R2 credentials:** Stored in `/opt/amina-travel/deploy/.env` (root-only readable)
2. **Encryption key:** Never committed to Git; backed up separately
3. **Temporary files:** Deleted immediately after upload
4. **Logs:** No secrets printed in logs (backup script sanitizes output)
5. **R2 access:** Token scoped to single bucket with read/write only
6. **Encrypted at rest:** Backups encrypted before leaving the server

---

## Cost Estimation

**Cloudflare R2 Pricing (as of 2026):**

### Free Tier (Recommended for Amina Travel)

- ✅ **10 GB storage/month** — FREE
- ✅ **1 million Class A operations/month** — FREE (writes)
- ✅ **10 million Class B operations/month** — FREE (reads)
- ✅ **Egress: FREE** (always, no egress charges)

**Your Expected Usage:**

- Database size: ~5 GB compressed
- 30 backups with cleanup: **~5-8 GB total** (under 10 GB limit)
- Daily operations: ~30 uploads/month (well under 1M limit)
- Occasional restores: negligible

**Total: $0/month** ✅ (stays within free tier)

### Paid Tier (Only if you exceed free tier)

- Storage: $0.015/GB/month (only above 10 GB)
- Class A operations: $4.50 per million (only above 1M)
- Class B operations: $0.36 per million (only above 10M)

**Example if you exceed free tier:**
- 30 GB storage: (30 - 10) × $0.015 = **$0.30/month**

**Maximum realistic cost: $0-1/month**

---

## Next Steps

1. ✅ Install AWS CLI
2. ✅ Configure R2 credentials in `.env`
3. ✅ Generate and backup encryption key
4. ✅ Test manual backup
5. ✅ Install systemd timer
6. ✅ Verify timer is scheduled
7. ✅ Perform a test restore to a test database
8. ✅ Document encryption key location
9. ✅ Set monthly restore test reminder

---

## Related Documentation

- [PRODUCTION_SERVER_HARDENING.md](./PRODUCTION_SERVER_HARDENING.md) — SSH hardening, disk cleanup, reboot procedure
- [DEVOPS.md](./DEVOPS.md) — Infrastructure architecture
- [DEPLOY.md](../deploy/DEPLOY.md) — Deployment runbook
