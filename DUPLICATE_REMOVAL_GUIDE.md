# Simple Duplicate Hotel Removal Guide

There are **3 ways** to remove duplicate hotels. Choose based on your comfort level:

---

## Option 1: Direct SQL Script (Fastest, Most Control)

### Prerequisites
- PostgreSQL client (`psql`) installed
- Database access credentials

### Steps

1. **Backup your database first:**
   ```bash
   pg_dump -U postgres -d amina_travel > backup_before_deduplication_$(date +%Y%m%d).sql
   ```

2. **Preview what will be deleted:**
   ```bash
   psql -U postgres -d amina_travel -f remove-duplicate-hotels.sql
   ```
   
   This shows:
   - All duplicate groups
   - Which hotels will be kept (✓ KEEP)
   - Which hotels will be deleted (✗ DELETE)
   - Summary statistics

3. **If the preview looks correct, edit the script:**
   - Open `remove-duplicate-hotels.sql`
   - Find the `DELETE` section at the bottom
   - Remove the `/*` and `*/` comment markers around it

4. **Run the deletion:**
   ```bash
   psql -U postgres -d amina_travel -f remove-duplicate-hotels.sql
   ```

5. **Verify on the website:**
   - Search for hotels in Djerba, Hammamet, etc.
   - Each hotel should appear only once

---

## Option 2: Using Admin UI (Existing Deduplication Page)

### Access
Navigate to: `http://admin.aminatravel.com/admin/hotels/deduplication`

### What it Does
The existing merge system will:
- Keep bookings safe (updates them to reference the kept hotel)
- Create URL redirects (old hotel URLs still work)
- Log everything for audit

### Steps

1. **Detection Tab:**
   - Click "Detect Duplicates"
   - Review the groups shown

2. **For each group:**
   - Choose which hotel to keep (green = recommended)
   - Click "Merge Hotels"
   - The duplicates are soft-deleted, not hard-deleted

3. **Result:**
   - Duplicates disappear from search
   - Original data preserved for safety

**Note:** This approach is safer but more complex - it preserves booking references even though you said you don't need that.

---

## Option 3: Manual Deletion via Admin UI

### Access
Navigate to: `http://admin.aminatravel.com/admin/hotels`

### Steps

1. **Search for a duplicate hotel:**
   - Enter hotel name in search box
   - Find duplicate entries

2. **Delete the unwanted ones:**
   - Click the trash icon on duplicate hotels
   - Keep only one hotel per property

3. **Repeat for all duplicates**

**Note:** This is tedious but gives you complete control over which specific hotel to delete.

---

## Recommended Approach

**If you're comfortable with SQL:** Use **Option 1** (SQL script)
- Fastest
- Most control
- Clean permanent deletion
- No merge complexity

**If you prefer UI:** Use **Option 2** (Deduplication page)
- Automated detection
- Safer (preserves data)
- Built-in logging

**If you want manual control:** Use **Option 3** (Manual deletion)
- Full control
- Good for selective cleanup
- Time-consuming for many duplicates

---

## After Deletion

### Verify the fix:
1. Visit your website's hotel search
2. Search for cities that had duplicates (Djerba, Hammamet, etc.)
3. Confirm each hotel appears only once

### Monitor:
- Check the "Review Needed" tab in the deduplication page
- This shows hotels flagged during supplier sync as potential future duplicates

---

## Rollback (if needed)

If using SQL script and something goes wrong:

```bash
# Restore from backup
psql -U postgres -d amina_travel < backup_before_deduplication_YYYYMMDD.sql
```

---

## Database Connection

If you need to connect to the database:

```bash
# Local development
psql -U postgres -d amina_travel

# Production (from .env file)
psql "$DATABASE_URL"
```

Get connection string from:
- Local: `backend/src/Amina.Travel.Api/appsettings.Development.json`
- Production: `.env` file or environment variables

---

## Questions?

- **How many duplicates do I have?** Run the SQL script preview (step 2 above)
- **Will this break bookings?** No bookings table found in Hotel entity
- **Can I undo?** Yes, restore from backup
- **Which hotels get kept?** Oldest by default (change `ORDER BY` in SQL to `DESC` for newest)

