# Cloudflare R2 Free Tier — Complete Guide

**Your backups will be 100% FREE using Cloudflare R2's free tier.**

---

## ✅ What's Included (FREE)

### Storage
- **10 GB per month** — FREE
- Your usage: ~5-8 GB (30 daily backups)
- **You stay well within the free tier**

### Operations
- **1 million Class A operations/month** — FREE (writes, lists, deletes)
- **10 million Class B operations/month** — FREE (reads)
- Your usage: ~30 uploads + ~30 deletes = 60 operations/month
- **You use 0.006% of the free limit**

### Bandwidth
- **Zero egress fees** — ALWAYS FREE
- No limits, no charges, forever
- Download/restore backups as much as you want: **$0**

---

## 📊 Your Usage Breakdown

### Database Size Estimate

**Typical PostgreSQL database sizes (compressed):**

| Scenario | Uncompressed | Compressed (gzip) | 30 Backups Total |
|----------|--------------|-------------------|------------------|
| Small (hotels only) | 500 MB | ~100 MB | 3 GB |
| Medium (hotels + bookings) | 2 GB | ~400 MB | 12 GB ⚠️ |
| Large (full production) | 5 GB | ~1 GB | 30 GB ⚠️ |

**Your likely scenario:** Small to Medium (~3-12 GB total)

### Staying Within Free Tier

**Strategy 1: Reduce retention (if needed)**

Instead of 30 days, use 7-14 days:

```bash
# Edit backup script
nano /opt/amina-travel/deploy/scripts/backup-postgres.sh

# Change RETENTION_DAYS from 30 to 7
RETENTION_DAYS=7
```

**With 7-day retention:**
- Daily backup: ~400 MB
- 7 backups total: **2.8 GB** ✅ (well within 10 GB free tier)

**Strategy 2: Monitor usage**

Check your R2 usage in Cloudflare dashboard:
1. Log in to Cloudflare
2. Go to R2 Object Storage
3. View bucket metrics
4. See current storage usage

**Strategy 3: Clean up manually if needed**

```bash
# List backups older than 7 days and delete manually
# See PRODUCTION_BACKUP.md for commands
```

---

## 🎯 Recommended Settings

### For Small Databases (<500 MB uncompressed)

```bash
RETENTION_DAYS=30  # Stay within 10 GB free tier
```

### For Medium Databases (500 MB - 2 GB uncompressed)

```bash
RETENTION_DAYS=14  # ~5-6 GB total, comfortably within free tier
```

### For Large Databases (>2 GB uncompressed)

```bash
RETENTION_DAYS=7   # ~2-3 GB total, well within free tier
```

**You can always adjust retention based on actual usage.**

---

## 💰 What If I Exceed 10 GB?

**Paid pricing is extremely cheap:**

- $0.015/GB/month for storage above 10 GB
- Example: 15 GB total = 5 GB × $0.015 = **$0.075/month** (7.5 cents)
- Example: 30 GB total = 20 GB × $0.015 = **$0.30/month** (30 cents)

**Even if you exceed, costs are minimal.**

---

## 🔍 How to Check Your Current Database Size

**Before setting up backups, check your database size:**

```bash
# SSH to server
ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169

# Check database size
docker exec amina-postgres psql -U amina -d amina_travel -c "
  SELECT 
    pg_size_pretty(pg_database_size('amina_travel')) as database_size,
    pg_size_pretty(pg_database_size('amina_travel') / 3) as estimated_compressed
  ;
"
```

**This shows:**
- Current database size (uncompressed)
- Estimated compressed size (roughly 1/3 of uncompressed)

**Example output:**

```
 database_size | estimated_compressed 
---------------+---------------------
 1536 MB       | 512 MB
```

**Calculate 30-day storage:**
- 512 MB × 30 = **15.36 GB** (exceeds free tier by 5.36 GB)
- **Cost if exceeded:** 5.36 × $0.015 = **$0.08/month** (8 cents)

**Or use 14-day retention:**
- 512 MB × 14 = **7.17 GB** ✅ (within free tier, $0/month)

---

## 📋 Setup Checklist for Free Tier

### 1. Check Current Database Size

```bash
docker exec amina-postgres psql -U amina -d amina_travel -c "
  SELECT pg_size_pretty(pg_database_size('amina_travel'));
"
```

### 2. Choose Retention Period

| Database Size | Recommended Retention | Total Storage | Cost |
|--------------|----------------------|---------------|------|
| < 300 MB | 30 days | < 10 GB | **$0** ✅ |
| 300-700 MB | 14 days | < 10 GB | **$0** ✅ |
| 700 MB - 1.4 GB | 7 days | < 10 GB | **$0** ✅ |
| > 1.4 GB | 7 days | May exceed | **$0-0.30/mo** |

### 3. Configure Retention in Backup Script

```bash
nano /opt/amina-travel/deploy/scripts/backup-postgres.sh

# Set RETENTION_DAYS based on table above
RETENTION_DAYS=14  # Adjust as needed
```

### 4. Monitor Usage After First Week

After 7 days of backups:

```bash
# Check R2 usage in Cloudflare dashboard
# Or list backups
source /opt/amina-travel/deploy/.env
AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
aws s3 ls s3://${R2_BUCKET}/backups/ \
  --endpoint-url "${R2_ENDPOINT}" \
  --recursive \
  --human-readable \
  --summarize
```

Look for: `Total Size:` at the end

### 5. Adjust If Needed

If total size > 9 GB after 7 days:
- Reduce retention to 7 or 14 days
- Or accept minimal cost ($0.10-0.30/month)

---

## 🎉 Bottom Line

**For most small-to-medium databases: FREE**

- Free tier: 10 GB storage
- Your usage: Likely 3-8 GB
- **Cost: $0/month** ✅

**Even if you exceed: Nearly free**

- 20 GB total: $0.15/month (15 cents)
- 30 GB total: $0.30/month (30 cents)
- **Still incredibly cheap**

**Recommendation:**

1. Start with 30-day retention
2. Monitor usage after first week
3. Adjust if needed (reduce to 14 or 7 days)
4. Enjoy free production-grade backups! 🎉

---

## 📚 Related Documentation

- [PRODUCTION_BACKUP.md](./PRODUCTION_BACKUP.md) — Complete backup guide
- [PRODUCTION_DEPLOYMENT_STEPS.md](../deploy/PRODUCTION_DEPLOYMENT_STEPS.md) — Deployment checklist
- [Cloudflare R2 Pricing](https://www.cloudflare.com/products/r2/) — Official pricing page

---

**Summary:** Your PostgreSQL backups will almost certainly be **100% FREE** using Cloudflare R2's generous free tier. Even if you exceed, costs are under $0.30/month.
