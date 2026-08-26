# Amina Travel — Production Server Hardening

Security hardening procedures for the production VPS.

---

## Overview

This document covers:

1. **SSH Hardening** — Disable password authentication, enforce key-only access
2. **Disk Cleanup** — Reclaim ~53 GB of Docker BuildKit cache
3. **Kernel Reboot** — Handle pending system updates safely
4. **Nginx Configuration** — Preserve production API timeout modifications
5. **Service Verification** — Ensure all services recover after reboot

---

## Current Server Status

**Audit Findings:**

```
✓ Operating System: Ubuntu 24.04 LTS
✓ Docker: Installed and working
✓ Docker Compose: Installed and working
✓ Services: All running (amina-nginx, amina-api, amina-web, amina-admin, amina-postgres)
✓ Firewall: UFW active (22, 80, 443 open)
✓ fail2ban: Active

⚠️ SSH: Password authentication enabled (security risk)
⚠️ SSH: Root login with password permitted (security risk)
⚠️ Disk: 84% full (53 GB reclaimable Docker cache)
⚠️ Kernel: Reboot required (/var/run/reboot-required exists)
⚠️ Nginx: Production /api/ timeout modification not in Git
```

---

## Part 1: SSH Hardening

### Current Configuration

SSH currently allows:

- ✅ SSH key authentication (working)
- ⚠️ Password authentication (enabled)
- ⚠️ Root login with password (enabled)

### Security Risk

Brute-force attacks can attempt password guessing. Even with fail2ban, this is unnecessary exposure.

### Prerequisites

**CRITICAL:** Before hardening SSH, verify key authentication works:

```bash
# From your local machine
ssh -i ~/.ssh/your-key root@162.35.185.169

# If this fails, DO NOT proceed with SSH hardening
```

If key authentication doesn't work:

1. Add your public key to `/root/.ssh/authorized_keys` on the server
2. Test again before proceeding

---

### Hardening Procedure

**Step 1:** Backup current SSH configuration

```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d)
```

**Step 2:** Modify SSH configuration

```bash
nano /etc/ssh/sshd_config
```

Find and change these lines:

```
# Before (insecure)
PasswordAuthentication yes
PermitRootLogin yes

# After (secure)
PasswordAuthentication no
PermitRootLogin prohibit-password
```

**Step 3:** Validate configuration

```bash
# Test syntax (must show no errors)
sshd -t

# If errors, DO NOT proceed. Fix configuration first.
```

**Step 4:** Apply changes

```bash
# Reload SSH (does NOT disconnect current sessions)
systemctl reload sshd

# Verify SSH is still running
systemctl status sshd
```

**Step 5:** Verify in a NEW terminal

**⚠️ DO NOT CLOSE YOUR CURRENT SSH SESSION YET**

Open a **new terminal** and test:

```bash
# This should work (key authentication)
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169

# This should fail (password authentication disabled)
ssh root@162.35.185.169
# Expected: "Permission denied (publickey)"
```

If key authentication works in the new terminal, it's safe to close the old session.

---

### Reverting SSH Changes (If Needed)

If you get locked out:

1. Access the server via VPS provider's console (web-based terminal)
2. Restore the backup:

```bash
cp /etc/ssh/sshd_config.backup-YYYYMMDD /etc/ssh/sshd_config
systemctl reload sshd
```

---

## Part 2: Disk Cleanup

### Current Disk Usage

```bash
# Check overall disk usage
df -h

# Check Docker disk usage
docker system df
```

Expected output:

```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          X GB      Y GB      Z GB      A GB (XX%)
Containers      X MB      Y MB      Z MB      A MB (XX%)
Local Volumes   X GB      Y GB      Z GB      A GB (XX%)
Build Cache     53 GB     0B        53 GB     53 GB (100%)  ← TARGET
```

### Safe Cleanup Procedure

**Step 1:** Verify running containers

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps

# Expected: all services "Up"
```

**Step 2:** List Docker volumes (DO NOT DELETE)

```bash
docker volume ls

# Expected output includes:
# amina-prod_pgdata  ← CRITICAL: PostgreSQL data
```

**⚠️ NEVER run `docker volume prune` without explicit verification**

**Step 3:** Clean build cache only

```bash
# Remove ALL build cache (safe - does not affect running containers or volumes)
docker builder prune -af

# Confirm when prompted
```

**Step 4:** Verify disk space reclaimed

```bash
df -h
docker system df
```

Expected result: ~53 GB freed, disk usage drops from 84% to ~30-40%.

---

### What NOT to Do

**❌ DO NOT run these commands:**

```bash
docker volume prune        # DANGER: Could delete PostgreSQL data
docker system prune --volumes -af   # DANGER: Deletes volumes
docker rm -f $(docker ps -aq)       # DANGER: Stops all containers
```

**✅ Safe cleanup commands:**

```bash
docker builder prune -af              # Safe: build cache only
docker image prune -a                 # Safe: unused images (but less space)
docker container prune                # Safe: stopped containers only
```

---

## Part 3: Kernel Reboot

### Why Reboot is Needed

`/var/run/reboot-required` exists, indicating:

- Kernel security updates installed but not active
- System is running an outdated kernel
- Reboot required to apply updates

### Pre-Reboot Checklist

1. ✅ All services using `restart: unless-stopped` (verified in `docker-compose.prod.yml`)
2. ✅ No active deployments in progress
3. ✅ Backup completed successfully (check systemd logs)
4. ✅ Off-hours timing (minimal user traffic)
5. ✅ Cloudflare in front (can show cached pages during brief restart)

---

### Reboot Procedure

**Step 1:** Verify Docker services will auto-restart

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml config | grep restart

# Expected: "restart: unless-stopped" for all services
```

**Step 2:** Optional - notify users

If you have a status page, post a brief maintenance notice.

**Step 3:** Initiate reboot

```bash
# Graceful reboot
reboot

# OR schedule for a specific time (e.g., 03:00)
shutdown -r 03:00
```

**Step 4:** Wait for server to come back (2-5 minutes)

**Step 5:** Verify services

```bash
# SSH back in
ssh -i ~/.ssh/your-key root@162.35.185.169

# Check all Docker services
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps

# All services should be "Up"
# If postgres is starting, give it 30 seconds then check again
```

**Step 6:** Verify application health

```bash
# API health check
curl -s http://localhost/health
# Expected: {"status":"ok",...}

# Website
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/
# Expected: 200

# Admin
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: admin.aminatravel.org' http://localhost/
# Expected: 200
```

**Step 7:** Verify kernel updated

```bash
uname -r
# Should show new kernel version

# Check reboot-required file removed
ls /var/run/reboot-required
# Expected: "No such file or directory"
```

---

### If Services Don't Start

If services don't come back automatically:

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml up -d
```

If Postgres is slow to start:

```bash
# Check Postgres logs
docker compose -f docker-compose.prod.yml logs postgres

# Wait for: "database system is ready to accept connections"
```

If API fails to start:

```bash
# Check API logs
docker compose -f docker-compose.prod.yml logs api

# Common issue: waiting for Postgres health check
# Give it 60 seconds, then check again
```

---

## Part 4: Nginx Configuration Preservation

### Issue

The production server has this modification in `deploy/nginx/templates/amina.conf.template`:

```nginx
location / {
    # Extended timeouts for TunisiaBeds availability searches
    proxy_read_timeout 130s;
    proxy_connect_timeout 130s;
    proxy_send_timeout 130s;
    
    proxy_pass http://api_upstream;
    # ... rest of config
}
```

**These timeouts are NOT in the Git version.** A fresh deployment would lose them.

### Why These Timeouts Exist

- TunisiaBeds API is slow (4+ seconds per request)
- Cloudflare timeout: 100s
- Backend timeout: 120s (configured in API)
- Nginx timeout: **130s** (must be higher than backend to avoid cutting off responses)

Without these, requests fail with 504 Gateway Timeout.

### Preservation Steps

The timeout configuration is **already correct in the current Git repository**. The nginx template at:

```
deploy/nginx/templates/amina.conf.template
```

Contains the correct timeouts in the `api.${DOMAIN}` server block. This was preserved during development.

### Verification

After any nginx configuration change:

```bash
# Test configuration syntax
docker compose -f docker-compose.prod.yml exec nginx nginx -t

# If valid, reload nginx
docker compose -f docker-compose.prod.yml restart nginx
```

---

## Part 5: Deployment Safety

### Before Any Deployment

```bash
cd /opt/amina-travel/deploy

# 1. Check running services
docker compose -f docker-compose.prod.yml ps

# 2. Check disk space
docker system df
df -h

# 3. Check recent backups
journalctl -u amina-postgres-backup.service -n 50 | grep "Backup Completed Successfully"
```

### Safe Deployment Process

```bash
cd /opt/amina-travel

# 1. Pull latest code
git pull
git submodule update --init --recursive

# 2. Rebuild and restart
cd deploy
docker compose -f docker-compose.prod.yml --env-file .env up -d --build

# 3. Always restart nginx after app rebuild
# (new container IPs need to be resolved)
docker compose -f docker-compose.prod.yml restart nginx

# 4. Verify health
sleep 5
curl -s http://localhost/health
```

### When to Rebuild Admin

The admin app must be rebuilt when:

- `front/apps/admin/` code changes
- `front/packages/` shared code changes (used by admin)
- `.env` changes `DOMAIN` or API URL

The Docker Compose `up --build` rebuilds all services automatically.

---

## Part 6: Service Monitoring

### Essential Health Checks

```bash
# Docker service status
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml ps

# Application health
curl -s http://localhost/health | jq .

# Nginx access logs (last 20 requests)
docker compose -f docker-compose.prod.yml logs --tail=20 nginx

# API logs (last 20 lines)
docker compose -f docker-compose.prod.yml logs --tail=20 api

# Postgres connections
docker exec amina-postgres psql -U amina -d amina_travel -c "SELECT count(*) FROM pg_stat_activity;"

# Disk space
df -h | grep -E "Filesystem|/dev/"
```

### Backup Verification

```bash
# Check last backup status
systemctl status amina-postgres-backup.service

# View backup logs
journalctl -u amina-postgres-backup.service -n 100

# Next scheduled backup
systemctl list-timers | grep amina
```

---

## Part 7: Firewall Configuration

### Current UFW Rules

```bash
ufw status verbose
```

Expected output:

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

**These are correct. Do not change.**

### Port Exposure

- **Port 22 (SSH):** Required for management
- **Port 80 (HTTP):** Required (Cloudflare connects via HTTP)
- **Port 443 (HTTPS):** Required for TLS origin cert (if enabled)
- **Port 5432 (PostgreSQL):** ✅ **NOT exposed** (correct - internal only)

### Verify PostgreSQL Not Exposed

```bash
# Should return nothing (port not listening on public interface)
netstat -tuln | grep 5432

# OR
ss -tuln | grep 5432

# Expected: Only 127.0.0.1:5432 or no output
# If 0.0.0.0:5432 appears, PostgreSQL is exposed - FIX IMMEDIATELY
```

---

## Security Checklist

After completing all hardening steps:

- [ ] SSH password authentication disabled
- [ ] SSH root login with password disabled  
- [ ] SSH key authentication working and verified
- [ ] Docker build cache cleaned (~53 GB freed)
- [ ] Kernel rebooted (no `/var/run/reboot-required`)
- [ ] All Docker services auto-restarted after reboot
- [ ] Nginx timeout configuration preserved
- [ ] PostgreSQL NOT exposed on public interface
- [ ] UFW firewall active (22, 80, 443 only)
- [ ] fail2ban running
- [ ] Backup system configured and tested
- [ ] Backup systemd timer active and scheduled

---

## Emergency Procedures

### SSH Locked Out

Access via VPS provider's web console:

1. Log in to VPS provider dashboard
2. Open web-based console/terminal
3. Restore SSH config: `cp /etc/ssh/sshd_config.backup-* /etc/ssh/sshd_config`
4. Reload: `systemctl reload sshd`

### Disk Full

```bash
# Emergency cleanup (be careful!)
docker builder prune -af
docker image prune -af

# Check for large logs
du -sh /var/lib/docker/containers/*
journalctl --disk-usage

# Rotate logs
journalctl --vacuum-size=500M
```

### Services Won't Start

```bash
# Check logs
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml logs --tail=100

# Force recreate
docker compose -f docker-compose.prod.yml up -d --force-recreate

# Last resort: full restart
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

### Database Restore Needed

See [PRODUCTION_BACKUP.md](./PRODUCTION_BACKUP.md) for full restore procedure.

---

## Related Documentation

- [PRODUCTION_BACKUP.md](./PRODUCTION_BACKUP.md) — Backup and restore procedures
- [DEVOPS.md](./DEVOPS.md) — Infrastructure architecture  
- [DEPLOY.md](../deploy/DEPLOY.md) — Deployment runbook
