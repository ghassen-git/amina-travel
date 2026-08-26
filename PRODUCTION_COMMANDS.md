# Amina Travel — Production Server Commands

**Quick reference for production deployment and operations.**

---

## 🚀 Initial Deployment (One-Time Setup)

### SSH Access

**Your SSH key is already configured:**
- Private key: `~/.ssh/amina_deploy_ed25519` (on your Mac)
- Public key already in `/root/.ssh/authorized_keys` on server

**Connect to production:**

```bash
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169
```

**Optional: Add SSH config for easier access:**

```bash
# On your Mac
cat >> ~/.ssh/config << 'EOF'

Host amina-prod
    HostName 162.35.185.169
    User root
    IdentityFile ~/.ssh/amina_deploy_ed25519
    IdentitiesOnly yes
EOF

# Then you can simply use:
ssh amina-prod
```

---

### 1. Install AWS CLI

```bash
ssh root@162.35.185.169
apt-get update
apt-get install -y awscli
aws --version
```

### 2. Pull Latest Code

```bash
cd /opt/amina-travel
git pull
git submodule update --init --recursive
```

### 3. Configure Environment Variables

```bash
cd /opt/amina-travel/deploy
nano .env
```

Add these lines:

```bash
# Cloudflare R2
R2_ENDPOINT=https://[account-id].r2.cloudflarestorage.com
R2_BUCKET=amina-travel-backups
R2_ACCESS_KEY_ID=[your-access-key]
R2_SECRET_ACCESS_KEY=[your-secret-key]

# Backup Encryption (generate with: openssl rand -base64 48)
BACKUP_ENCRYPTION_KEY=[your-generated-key]
```

Save and secure:

```bash
chmod 600 .env
```

### 4. Make Backup Script Executable

```bash
chmod +x /opt/amina-travel/deploy/scripts/backup-postgres.sh
```

### 5. Test Backup

```bash
cd /opt/amina-travel/deploy
source .env
DRY_RUN=1 ./scripts/backup-postgres.sh
```

Then run for real:

```bash
./scripts/backup-postgres.sh
```

### 6. Install Systemd Timer

```bash
cp /opt/amina-travel/deploy/systemd/amina-postgres-backup.service /etc/systemd/system/
cp /opt/amina-travel/deploy/systemd/amina-postgres-backup.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable amina-postgres-backup.timer
systemctl start amina-postgres-backup.timer
```

Verify:

```bash
systemctl list-timers | grep amina
```

### 7. Harden SSH (After verifying key auth works!)

**First verify your SSH key works:**

```bash
# From your Mac
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169
```

**Then harden SSH configuration:**

```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d)
nano /etc/ssh/sshd_config
```

Change:
- `PasswordAuthentication no`
- `PermitRootLogin prohibit-password`

Then:

```bash
sshd -t
systemctl reload sshd
```

Test in a NEW terminal before closing current session!

### 8. Clean Docker Cache

```bash
docker system df
docker builder prune -af
df -h
```

### 9. Reboot (During maintenance window)

```bash
reboot
```

After 2-5 minutes, verify:

```bash
ssh root@162.35.185.169
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps
curl -s http://localhost/health
```

---

## 📊 Daily Operations

### Check Service Status

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps
```

### View Application Logs

```bash
docker compose -f docker-compose.prod.yml logs -f api
docker compose -f docker-compose.prod.yml logs -f web
docker compose -f docker-compose.prod.yml logs -f nginx
```

### Check Backup Status

```bash
systemctl status amina-postgres-backup.timer
journalctl -u amina-postgres-backup.service -n 50
```

### Manual Backup

```bash
systemctl start amina-postgres-backup.service
```

### Check Disk Space

```bash
df -h
docker system df
```

---

## 🔄 Application Updates

### Deploy Latest Code

```bash
cd /opt/amina-travel
git pull
git submodule update --init --recursive
cd deploy
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
docker compose -f docker-compose.prod.yml restart nginx
```

### Verify Deployment

```bash
sleep 5
curl -s http://localhost/health
docker compose -f docker-compose.prod.yml ps
```

---

## 💾 Backup Operations

### List Backups in R2

```bash
cd /opt/amina-travel/deploy
source .env
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 ls s3://${R2_BUCKET}/backups/ \
  --endpoint-url "${R2_ENDPOINT}" \
  --recursive \
  --human-readable
```

### Test Restore (Recommended Monthly)

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
aws s3 cp "s3://${R2_BUCKET}/backups/${LATEST_BACKUP}" /tmp/test.sql.gz.enc \
  --endpoint-url "${R2_ENDPOINT}"

# Decrypt and decompress
openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
  -in /tmp/test.sql.gz.enc \
  -out /tmp/test.sql.gz \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}"

gunzip /tmp/test.sql.gz

# Create test database
docker exec amina-postgres psql -U amina -c "CREATE DATABASE amina_travel_test;"

# Restore
docker exec -i amina-postgres psql -U amina -d amina_travel_test < /tmp/test.sql

# Verify
docker exec amina-postgres psql -U amina -d amina_travel_test -c "
  SELECT schemaname, COUNT(*) as tables
  FROM pg_tables 
  WHERE schemaname IN ('hotels', 'bookings', 'payments', 'auth')
  GROUP BY schemaname;
"

# Cleanup
docker exec amina-postgres psql -U amina -c "DROP DATABASE amina_travel_test;"
rm -f /tmp/test.sql /tmp/test.sql.gz.enc
```

---

## 🔍 Monitoring & Health Checks

### Application Health

```bash
curl -s http://localhost/health | jq .
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: admin.aminatravel.org' http://localhost/
```

### Database Connections

```bash
docker exec amina-postgres psql -U amina -d amina_travel -c "
  SELECT count(*) as connections, state 
  FROM pg_stat_activity 
  GROUP BY state;
"
```

### System Resources

```bash
free -h
df -h
docker stats --no-stream
```

### Recent Errors in Logs

```bash
docker compose -f docker-compose.prod.yml logs --tail=100 | grep -i error
journalctl -u amina-postgres-backup.service | grep -i error
```

---

## 🔧 Troubleshooting

### Services Not Starting

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

### Check Container Logs

```bash
docker compose -f docker-compose.prod.yml logs --tail=100 api
docker compose -f docker-compose.prod.yml logs --tail=100 postgres
```

### Restart Specific Service

```bash
docker compose -f docker-compose.prod.yml restart api
docker compose -f docker-compose.prod.yml restart nginx
```

### Database Connection Issues

```bash
docker exec amina-postgres psql -U amina -d amina_travel -c "SELECT 1;"
```

### Backup Failures

```bash
journalctl -u amina-postgres-backup.service -n 100 --no-pager
```

### Disk Space Issues

```bash
docker builder prune -af
docker image prune -af
journalctl --vacuum-size=500M
```

---

## 🔐 Security Verification

### Verify SSH Configuration

```bash
grep -E "^PasswordAuthentication|^PermitRootLogin" /etc/ssh/sshd_config
```

Expected:
```
PasswordAuthentication no
PermitRootLogin prohibit-password
```

### Verify PostgreSQL Not Exposed

```bash
ss -tuln | grep 5432
```

Expected: Only `127.0.0.1:5432` or no output (not `0.0.0.0:5432`)

### Verify Firewall

```bash
ufw status
```

Expected: Only ports 22, 80, 443 open

### Check Backup Timer

```bash
systemctl is-active amina-postgres-backup.timer
systemctl is-enabled amina-postgres-backup.timer
```

Expected: `active` and `enabled`

---

## 📞 Emergency Procedures

### Complete Service Restart

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml restart
```

### Force Rebuild

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d --build --force-recreate
```

### Emergency Backup Before Dangerous Operation

```bash
cd /opt/amina-travel/deploy
source .env
./scripts/backup-postgres.sh
```

### Restore SSH Access (via VPS console)

```bash
cp /etc/ssh/sshd_config.backup-YYYYMMDD /etc/ssh/sshd_config
systemctl reload sshd
```

---

## 📋 Weekly Checklist

```bash
# Check backup logs
journalctl -u amina-postgres-backup.service --since "1 week ago" | grep "Successfully"

# Check disk space
df -h

# Check service status
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps

# Check application health
curl -s http://localhost/health | jq .
```

---

## 📋 Monthly Checklist

```bash
# Test restore (see "Test Restore" section above)

# Check for system updates
apt-get update
apt-get upgrade

# Review backup retention
cd /opt/amina-travel/deploy
source .env
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 ls s3://${R2_BUCKET}/backups/ --endpoint-url "${R2_ENDPOINT}" --recursive

# Check Docker disk usage
docker system df
```

---

## 📚 Documentation Links

- Full backup guide: `docs/PRODUCTION_BACKUP.md`
- Server hardening: `docs/PRODUCTION_SERVER_HARDENING.md`
- Deployment steps: `deploy/PRODUCTION_DEPLOYMENT_STEPS.md`
- Implementation summary: `IMPLEMENTATION_SUMMARY.md`

---

## 🆘 Quick Help

```bash
# Backup logs
journalctl -u amina-postgres-backup.service -n 50

# Service status
systemctl status amina-postgres-backup.timer

# Application logs
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml logs -f

# Disk usage
df -h && docker system df

# Health check
curl -s http://localhost/health
```

---

**Production Server:** 162.35.185.169  
**Working Directory:** /opt/amina-travel  
**Compose Directory:** /opt/amina-travel/deploy
