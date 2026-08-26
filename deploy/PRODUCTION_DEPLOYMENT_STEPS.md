# Amina Travel — Production Deployment Steps

**Complete step-by-step checklist for deploying backup system and server hardening.**

---

## Prerequisites

- [x] SSH access to production server (162.35.185.169)
- [x] Root or sudo privileges
- [x] Cloudflare account with R2 access
- [x] This repository pulled with latest changes

---

## Phase 1: Backup System Installation

### Step 1.1: Install AWS CLI

```bash
ssh root@162.35.185.169

apt-get update
apt-get install -y awscli

# Verify
aws --version
```

### Step 1.2: Configure Cloudflare R2

**On Cloudflare Dashboard:**

1. Navigate to **R2 Object Storage**
2. Click **Create bucket**
   - Name: `amina-travel-backups`
   - Location: Choose closest to server
3. Click **Manage R2 API Tokens**
4. Click **Create API token**
   - Token name: `amina-backup-system`
   - Permissions: **Object Read & Write**
   - Specify bucket: `amina-travel-backups`
5. Copy the credentials:
   - **Access Key ID**
   - **Secret Access Key**  
   - **Endpoint URL** (format: `https://[account-id].r2.cloudflarestorage.com`)

### Step 1.3: Generate Encryption Key

**On your local machine:**

```bash
openssl rand -base64 48
```

**⚠️ CRITICAL:** Save this key in 3 places:

1. Password manager (1Password, LastPass, Bitwarden)
2. Secure company documentation
3. Print and store in physical safe

**DO NOT** store only on the production server.

### Step 1.4: Update Production .env

**On production server:**

```bash
cd /opt/amina-travel/deploy
nano .env
```

Add these lines at the end:

```bash
# Cloudflare R2 Backup Configuration
R2_ENDPOINT=https://[your-account-id].r2.cloudflarestorage.com
R2_BUCKET=amina-travel-backups
R2_ACCESS_KEY_ID=[paste-access-key-id]
R2_SECRET_ACCESS_KEY=[paste-secret-access-key]

# Backup Encryption Key (MUST be ≥32 characters)
BACKUP_ENCRYPTION_KEY=[paste-generated-key]
```

Save and secure the file:

```bash
chmod 600 .env
```

### Step 1.5: Deploy Backup Script

**Pull latest changes:**

```bash
cd /opt/amina-travel
git pull
git submodule update --init --recursive
```

**Make script executable:**

```bash
chmod +x /opt/amina-travel/deploy/scripts/backup-postgres.sh
```

### Step 1.6: Test Backup (Dry Run)

```bash
cd /opt/amina-travel/deploy
source .env

# Test without uploading
DRY_RUN=1 ./scripts/backup-postgres.sh
```

Expected output:

```
[YYYY-MM-DD HH:MM:SS UTC] Validating environment...
[YYYY-MM-DD HH:MM:SS UTC] ✓ Environment validation passed
[YYYY-MM-DD HH:MM:SS UTC] Creating PostgreSQL backup...
[YYYY-MM-DD HH:MM:SS UTC] [DRY RUN] Would upload...
[YYYY-MM-DD HH:MM:SS UTC] ✓ ==================== Backup Completed Successfully ====================
```

### Step 1.7: Run Real Backup

```bash
cd /opt/amina-travel/deploy
source .env
./scripts/backup-postgres.sh
```

Verify success:

```bash
# Check script output for "Backup Completed Successfully"

# Verify in R2
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 ls s3://${R2_BUCKET}/backups/ --endpoint-url "${R2_ENDPOINT}"
```

You should see: `amina_travel_YYYY-MM-DD_HHMMSS.sql.gz.enc`

### Step 1.8: Install Systemd Timer

```bash
# Copy systemd files
cp /opt/amina-travel/deploy/systemd/amina-postgres-backup.service /etc/systemd/system/
cp /opt/amina-travel/deploy/systemd/amina-postgres-backup.timer /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable and start timer
systemctl enable amina-postgres-backup.timer
systemctl start amina-postgres-backup.timer

# Verify timer is active
systemctl status amina-postgres-backup.timer
systemctl list-timers | grep amina
```

Expected output:

```
amina-postgres-backup.timer loaded active waiting
```

### Step 1.9: Test Restore (IMPORTANT)

Create a test database and restore:

```bash
cd /opt/amina-travel/deploy
source .env

# Download latest backup
LATEST_BACKUP=$(AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
                AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
                aws s3 ls s3://${R2_BUCKET}/backups/ --endpoint-url "${R2_ENDPOINT}" \
                | awk '{print $4}' | tail -1)

AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 cp "s3://${R2_BUCKET}/backups/${LATEST_BACKUP}" /tmp/test-restore.sql.gz.enc \
  --endpoint-url "${R2_ENDPOINT}"

# Decrypt and decompress
openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
  -in /tmp/test-restore.sql.gz.enc \
  -out /tmp/test-restore.sql.gz \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}"

gunzip /tmp/test-restore.sql.gz

# Create test database
docker exec amina-postgres psql -U amina -c "CREATE DATABASE amina_travel_test;"

# Restore
docker exec -i amina-postgres psql -U amina -d amina_travel_test < /tmp/test-restore.sql

# Verify tables exist
docker exec amina-postgres psql -U amina -d amina_travel_test -c "
  SELECT schemaname, COUNT(*) as table_count
  FROM pg_tables 
  WHERE schemaname IN ('hotels', 'bookings', 'payments', 'auth')
  GROUP BY schemaname
  ORDER BY schemaname;
"

# Clean up
docker exec amina-postgres psql -U amina -c "DROP DATABASE amina_travel_test;"
rm -f /tmp/test-restore.sql /tmp/test-restore.sql.gz.enc
```

If you see hotel, bookings, payments, and auth schemas with tables: **✅ Backup system is working**

---

## Phase 2: Server Hardening

### Step 2.1: Verify SSH Key Authentication

**From your local machine:**

```bash
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169
```

**⚠️ If this fails, DO NOT proceed with SSH hardening. Fix key authentication first.**

**Note:** Your SSH key is located at:
- Private key: `~/.ssh/amina_deploy_ed25519` (permissions: 600)
- Public key: `~/.ssh/amina_deploy_ed25519.pub`
- Server authorized_keys: `/root/.ssh/authorized_keys` (already configured)

### Step 2.2: Harden SSH Configuration

**On production server:**

```bash
# Backup current config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d)

# Edit config
nano /etc/ssh/sshd_config
```

Find and change:

```
PasswordAuthentication no
PermitRootLogin prohibit-password
```

Save and test:

```bash
# Validate configuration
sshd -t

# If no errors, reload SSH
systemctl reload sshd

# Verify SSH still running
systemctl status sshd
```

### Step 2.3: Test SSH in New Terminal

**⚠️ DO NOT close current SSH session yet**

**Open a NEW terminal on your local machine:**

```bash
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169
```

If successful: ✅ SSH hardening complete. You can close the old session.

If failed: Use the old session to restore backup config.

---

## Phase 3: Disk Cleanup

### Step 3.1: Check Current Disk Usage

```bash
df -h
docker system df
```

Note the "Build Cache" size (should be ~53 GB).

### Step 3.2: Verify Running Services

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps
```

All services should show "Up".

### Step 3.3: Clean Build Cache

```bash
# Remove build cache (safe - does not affect running containers)
docker builder prune -af

# Confirm when prompted
```

### Step 3.4: Verify Space Freed

```bash
df -h
docker system df
```

Disk usage should drop from ~84% to ~30-40%.

---

## Phase 4: Kernel Reboot

### Step 4.1: Verify Reboot Required

```bash
ls /var/run/reboot-required
```

If file exists: reboot needed.

### Step 4.2: Pre-Reboot Checklist

```bash
# Verify services will auto-restart
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml config | grep restart

# Expected: "restart: unless-stopped" for all services

# Verify recent backup exists
journalctl -u amina-postgres-backup.service -n 20 | grep "Successfully"
```

### Step 4.3: Schedule Reboot

**Option A: Immediate reboot** (during off-hours)

```bash
reboot
```

**Option B: Schedule for specific time**

```bash
# Example: reboot at 3 AM
shutdown -r 03:00
```

### Step 4.4: Verify After Reboot

Wait 2-5 minutes, then SSH back in:

```bash
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169
```

**Check services:**

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps
```

All services should be "Up". If Postgres is starting, wait 30 seconds.

**Verify health:**

```bash
curl -s http://localhost/health
# Expected: {"status":"ok",...}

curl -s -o /dev/null -w '%{http_code}\n' http://localhost/
# Expected: 200
```

**Verify reboot-required gone:**

```bash
ls /var/run/reboot-required
# Expected: "No such file or directory"
```

---

## Phase 5: Verification & Monitoring

### Step 5.1: Verify Backup Timer

```bash
# Check timer status
systemctl status amina-postgres-backup.timer

# View next scheduled run
systemctl list-timers | grep amina

# View recent backup logs
journalctl -u amina-postgres-backup.service -n 50
```

### Step 5.2: Verify SSH Hardening

```bash
# Check SSH config
grep -E "^PasswordAuthentication|^PermitRootLogin" /etc/ssh/sshd_config

# Expected:
# PasswordAuthentication no
# PermitRootLogin prohibit-password
```

### Step 5.3: Verify Disk Space

```bash
df -h | grep -E "Filesystem|/dev/"

# Expected: < 50% used
```

### Step 5.4: Verify PostgreSQL Not Exposed

```bash
ss -tuln | grep 5432

# Expected: Only 127.0.0.1:5432 or no output
# If 0.0.0.0:5432 appears: SECURITY ISSUE - investigate immediately
```

### Step 5.5: Verify Firewall

```bash
ufw status verbose

# Expected:
# 22/tcp ALLOW
# 80/tcp ALLOW  
# 443/tcp ALLOW
# Status: active
```

---

## Final Checklist

After completing all phases:

- [ ] AWS CLI installed
- [ ] R2 bucket created (`amina-travel-backups`)
- [ ] R2 credentials configured in `/opt/amina-travel/deploy/.env`
- [ ] Encryption key generated and backed up in 3 places
- [ ] Backup script tested (dry run + real run)
- [ ] Backup exists in R2
- [ ] Test restore successful
- [ ] Systemd timer installed and active
- [ ] Timer shows next scheduled run
- [ ] SSH key authentication verified working
- [ ] SSH password authentication disabled
- [ ] SSH root login with password disabled
- [ ] Docker build cache cleaned (~53 GB freed)
- [ ] Disk usage < 50%
- [ ] System rebooted
- [ ] All Docker services auto-started after reboot
- [ ] Application health checks passing
- [ ] `/var/run/reboot-required` removed
- [ ] PostgreSQL NOT exposed publicly
- [ ] Firewall rules correct

---

## Ongoing Maintenance

### Daily (Automatic)

- Backup runs at 02:00 server time
- Old backups (>30 days) automatically deleted

### Weekly

```bash
# Check backup logs
journalctl -u amina-postgres-backup.service --since "1 week ago" | grep -E "Successfully|ERROR"

# Check disk space
df -h
```

### Monthly

```bash
# Test restore to verify backups are recoverable
# See PRODUCTION_BACKUP.md for detailed restore procedure

# Check for system updates
apt-get update
apt-get upgrade

# If kernel updated, schedule reboot
```

### As Needed

```bash
# Manual backup before risky changes
cd /opt/amina-travel/deploy
source .env
./scripts/backup-postgres.sh

# View specific backup logs
journalctl -u amina-postgres-backup.service --since "2026-08-26"
```

---

## Troubleshooting

### Backup Fails

```bash
# Check logs
journalctl -u amina-postgres-backup.service -n 100

# Common issues:
# - Container not running: docker ps | grep postgres
# - Invalid R2 credentials: test with aws s3 ls
# - Encryption key wrong: check .env
```

### Services Don't Start After Reboot

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml up -d
```

### SSH Locked Out

Access via VPS provider web console, then:

```bash
cp /etc/ssh/sshd_config.backup-YYYYMMDD /etc/ssh/sshd_config
systemctl reload sshd
```

---

## Related Documentation

- [PRODUCTION_BACKUP.md](../docs/PRODUCTION_BACKUP.md) — Detailed backup & restore procedures
- [PRODUCTION_SERVER_HARDENING.md](../docs/PRODUCTION_SERVER_HARDENING.md) — Detailed hardening guide
- [DEPLOY.md](./DEPLOY.md) — Standard deployment runbook
- [DEVOPS.md](../docs/DEVOPS.md) — Infrastructure architecture

---

## Support

For issues or questions:

1. Check logs: `journalctl -u amina-postgres-backup.service -n 100`
2. Review documentation linked above
3. Contact system administrator
