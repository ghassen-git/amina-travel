# Git Commit Guide — Production Backup & Server Hardening

**What to commit to Git and deployment instructions.**

---

## ✅ Files to Commit

### New Files (git add)

```bash
cd /Users/macos/Desktop/amina-travel

# Documentation
git add docs/PRODUCTION_BACKUP.md
git add docs/PRODUCTION_SERVER_HARDENING.md

# Deployment guides
git add deploy/PRODUCTION_DEPLOYMENT_STEPS.md
git add IMPLEMENTATION_SUMMARY.md
git add PRODUCTION_COMMANDS.md
git add GIT_COMMIT_GUIDE.md

# Backup scripts
git add deploy/scripts/backup-postgres.sh
git add deploy/scripts/README.md

# Systemd configuration
git add deploy/systemd/amina-postgres-backup.service
git add deploy/systemd/amina-postgres-backup.timer

# Modified files
git add .gitignore
git add deploy/.env.production.example
```

### Files to EXCLUDE (already in .gitignore)

```bash
# These should NOT be committed:
.env                          # Contains production secrets
backups/                      # Backup files
*.sql, *.sql.gz, *.sql.gz.enc # Database dumps
.claude/                      # IDE configuration
```

---

## 📝 Suggested Commit Message

```
feat: Add production backup system and server hardening

Implements comprehensive PostgreSQL backup system with Cloudflare R2 and
security hardening procedures for production server.

Features:
- Daily automated PostgreSQL backups to Cloudflare R2
- AES-256-CBC encryption before upload
- 30-day retention with automatic cleanup
- Systemd timer for daily execution (02:00)
- Host-level backup (independent from containers)
- Comprehensive restore procedures

Server Hardening:
- SSH hardening procedures (disable password auth)
- Disk cleanup procedures (Docker BuildKit cache)
- Kernel reboot procedures with service verification
- Security verification checklists

Documentation:
- Complete backup & restore guide (PRODUCTION_BACKUP.md)
- Server hardening guide (PRODUCTION_SERVER_HARDENING.md)
- Step-by-step deployment checklist (PRODUCTION_DEPLOYMENT_STEPS.md)
- Quick command reference (PRODUCTION_COMMANDS.md)

Scripts:
- backup-postgres.sh: Automated backup script with encryption
- Systemd service & timer for daily execution
- Dry-run mode for testing

Safety:
- No automatic destructive operations
- All restore operations require manual execution
- PostgreSQL data fully protected
- Temporary files cleaned up after upload
- No secrets committed to Git

Closes: Production backup requirement
Related: Server hardening and security audit
```

---

## 🚀 Commit Commands

```bash
cd /Users/macos/Desktop/amina-travel

# Stage all new files
git add docs/PRODUCTION_BACKUP.md
git add docs/PRODUCTION_SERVER_HARDENING.md
git add deploy/PRODUCTION_DEPLOYMENT_STEPS.md
git add deploy/scripts/
git add deploy/systemd/
git add IMPLEMENTATION_SUMMARY.md
git add PRODUCTION_COMMANDS.md
git add GIT_COMMIT_GUIDE.md

# Stage modified files
git add .gitignore
git add deploy/.env.production.example

# Review what will be committed
git status

# Verify no secrets are being committed
git diff --cached | grep -i "password\|secret\|key" | grep -v "CHANGE_ME\|<\|#"

# Commit
git commit -m "feat: Add production backup system and server hardening

Implements comprehensive PostgreSQL backup system with Cloudflare R2 and
security hardening procedures for production server.

Features:
- Daily automated PostgreSQL backups to Cloudflare R2
- AES-256-CBC encryption before upload
- 30-day retention with automatic cleanup
- Systemd timer for daily execution (02:00)
- Comprehensive documentation and deployment guides

Server Hardening:
- SSH hardening procedures
- Disk cleanup procedures
- Security verification checklists

Safety:
- No automatic destructive operations
- PostgreSQL data fully protected
- No secrets committed to Git
"

# Push to remote
git push origin main
```

---

## 🔒 Security Verification Before Push

**CRITICAL: Run these checks before pushing:**

```bash
# 1. Check no .env is staged
git status | grep "\.env$"
# Expected: Nothing (only .env.example should appear)

# 2. Check for secrets in staged files
git diff --cached | grep -E "R2_SECRET_ACCESS_KEY=.+" | grep -v "R2_SECRET_ACCESS_KEY=$"
git diff --cached | grep -E "BACKUP_ENCRYPTION_KEY=.+" | grep -v "BACKUP_ENCRYPTION_KEY=$"
# Expected: Nothing (only empty values or placeholders)

# 3. Verify .gitignore includes backup files
git diff --cached .gitignore | grep "backups/"
# Expected: Should see "+backups/"

# 4. Check backup script doesn't contain hardcoded secrets
grep -E "R2_SECRET|BACKUP_ENCRYPTION_KEY" deploy/scripts/backup-postgres.sh | grep -v "\${" | grep -v "^#"
# Expected: Nothing (only variable references like ${R2_SECRET_ACCESS_KEY})
```

If any of these checks fail, **DO NOT PUSH**. Fix the issues first.

---

## 📦 Deployment to Production Server

**After pushing to Git:**

```bash
# SSH to production server (from your Mac)
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169

# Pull latest code
cd /opt/amina-travel
git pull
git submodule update --init --recursive

# Follow deployment guide
cat deploy/PRODUCTION_DEPLOYMENT_STEPS.md
```

**Or use the quick deployment guide:**

```bash
cat PRODUCTION_COMMANDS.md
```

---

## 📋 Pre-Deployment Checklist

Before deploying to production:

- [ ] All tests passed locally
- [ ] No secrets in Git
- [ ] `.env.production.example` updated with new variables
- [ ] `.gitignore` updated
- [ ] Documentation complete and reviewed
- [ ] Backup script tested (dry-run)
- [ ] Systemd files validated
- [ ] Deployment steps documented
- [ ] Rollback procedures documented
- [ ] Team notified of upcoming changes

---

## 🔄 Post-Deployment Verification

After deploying to production:

```bash
# SSH to server (from your Mac)
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169

# Verify backup script is executable
ls -la /opt/amina-travel/deploy/scripts/backup-postgres.sh
# Expected: -rwxr-xr-x (executable)

# Verify systemd files exist
ls -la /etc/systemd/system/amina-postgres-backup.*
# Expected: service and timer files

# Test backup (after configuring .env)
cd /opt/amina-travel/deploy
source .env
DRY_RUN=1 ./scripts/backup-postgres.sh

# Check timer status
systemctl status amina-postgres-backup.timer
systemctl list-timers | grep amina
```

---

## 📚 Files Created Summary

### Documentation (7 files)

1. `docs/PRODUCTION_BACKUP.md` — Complete backup & restore guide
2. `docs/PRODUCTION_SERVER_HARDENING.md` — Server hardening procedures
3. `deploy/PRODUCTION_DEPLOYMENT_STEPS.md` — Step-by-step deployment
4. `deploy/scripts/README.md` — Scripts documentation
5. `IMPLEMENTATION_SUMMARY.md` — Implementation overview
6. `PRODUCTION_COMMANDS.md` — Quick command reference
7. `GIT_COMMIT_GUIDE.md` — This file

### Scripts (1 file)

1. `deploy/scripts/backup-postgres.sh` — Automated backup script

### Systemd Configuration (2 files)

1. `deploy/systemd/amina-postgres-backup.service`
2. `deploy/systemd/amina-postgres-backup.timer`

### Modified Files (2 files)

1. `.gitignore` — Added backup file patterns
2. `deploy/.env.production.example` — Added R2 and backup variables

**Total: 12 files (10 new, 2 modified)**

---

## 🎯 What This Achieves

### Production Backup System

✅ Daily automated backups to Cloudflare R2  
✅ Encryption before upload (AES-256-CBC)  
✅ 30-day retention with automatic cleanup  
✅ Independent from application containers  
✅ Comprehensive restore procedures  
✅ Test restore procedures documented  

### Server Hardening

✅ SSH hardening procedures  
✅ Disk cleanup procedures  
✅ Kernel reboot procedures  
✅ Security verification checklists  
✅ Emergency rollback procedures  

### Documentation

✅ Complete implementation guide  
✅ Step-by-step deployment checklist  
✅ Quick command reference  
✅ Troubleshooting guides  
✅ Ongoing maintenance procedures  

### Safety

✅ No automatic destructive operations  
✅ All dangerous operations require manual execution  
✅ PostgreSQL data fully protected  
✅ No secrets committed to Git  
✅ Comprehensive testing procedures  

---

## 🆘 If Something Goes Wrong

### Revert Git Changes

```bash
git reset --hard HEAD~1  # Undo last commit (before push)
git revert HEAD          # Create revert commit (after push)
```

### Remove from Production

```bash
ssh root@162.35.185.169

# Stop and disable timer
systemctl stop amina-postgres-backup.timer
systemctl disable amina-postgres-backup.timer

# Remove systemd files
rm /etc/systemd/system/amina-postgres-backup.*
systemctl daemon-reload

# Production continues normally (backup is read-only)
```

---

## ✅ Final Checks

Before considering this complete:

- [ ] All files committed to Git
- [ ] No secrets in Git repository
- [ ] Git pushed to remote
- [ ] Production server updated (`git pull`)
- [ ] Backup script tested on production
- [ ] Systemd timer installed and active
- [ ] Test restore completed successfully
- [ ] SSH hardening completed (if applicable)
- [ ] Disk cleanup completed (if applicable)
- [ ] Documentation reviewed by team
- [ ] Encryption key backed up in 3 places

---

**Implementation Date:** August 26, 2026  
**Repository:** https://github.com/ghassen-git/amina-travel  
**Production Server:** 162.35.185.169
