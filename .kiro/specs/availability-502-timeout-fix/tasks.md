# Implementation Tasks

## Task 1: Update HTTP Nginx Configuration ⬜ NOT_STARTED

**Description:** Update the HTTP nginx configuration template to add extended proxy timeouts for API endpoints.

**Files to Modify:**
- `deploy/nginx/templates/amina.conf.template`

**Changes Required:**

1. Locate the API server block (`server_name api.${DOMAIN};`)
2. Add timeout directives to the `location /` block within the API server:
   ```nginx
   # Timeout hierarchy: Cloudflare (100s) -> Backend (120s) -> Nginx (130s buffer)
   # Extended timeouts for slow TunisiaBeds availability searches (4+ seconds per request)
   proxy_read_timeout 130s;      # Time to read response from backend
   proxy_connect_timeout 130s;   # Time to establish connection to backend
   proxy_send_timeout 130s;      # Time to send request to backend
   ```
3. Place these directives BEFORE the existing `proxy_pass` directive
4. Ensure proper indentation (8 spaces to match existing location block)

**Acceptance Criteria:**
- [ ] Timeout directives added to API location block only (not website or admin)
- [ ] Values are exactly 130s for all three timeout types
- [ ] Comment explains the timeout hierarchy
- [ ] Indentation matches existing nginx configuration style
- [ ] File syntax is valid (no typos in directive names)

**Validation:**
```bash
# Validate nginx config syntax (after deployment)
docker exec amina-prod-nginx-1 nginx -t
```

---

## Task 2: Update HTTPS Nginx Configuration ⬜ NOT_STARTED

**Description:** Update the HTTPS nginx configuration template to add the same extended proxy timeouts for API endpoints over SSL.

**Files to Modify:**
- `deploy/nginx/templates/tls.conf.template`

**Changes Required:**

1. Locate the HTTPS API server block (`server_name api.${DOMAIN};` with `listen 443 ssl;`)
2. Add the same timeout directives to the `location /` block:
   ```nginx
   # Timeout hierarchy: Cloudflare (100s) -> Backend (120s) -> Nginx (130s buffer)
   # Extended timeouts for slow TunisiaBeds availability searches (4+ seconds per request)
   proxy_read_timeout 130s;      # Time to read response from backend
   proxy_connect_timeout 130s;   # Time to establish connection to backend
   proxy_send_timeout 130s;      # Time to send request to backend
   ```
3. Place these directives BEFORE the existing `proxy_pass` directive
4. Ensure proper indentation (8 spaces to match existing location block)

**Acceptance Criteria:**
- [ ] Timeout directives added to HTTPS API location block only
- [ ] Values match Task 1 exactly (130s for all three types)
- [ ] Comment is identical to Task 1 for consistency
- [ ] Indentation matches existing nginx configuration style
- [ ] File syntax is valid

**Validation:**
```bash
# Validate nginx config syntax (after deployment)
docker exec amina-prod-nginx-1 nginx -t
```

---

## Task 3: Deploy Configuration Changes ⬜ NOT_STARTED

**Description:** Deploy the updated nginx configuration to the production server and restart the nginx container.

**Prerequisites:**
- Tasks 1 and 2 must be completed
- Changes committed to git main branch
- SSH access to production server (162.35.185.169)

**Deployment Steps:**

1. SSH to production server:
   ```bash
   ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169
   ```

2. Navigate to deployment directory:
   ```bash
   cd /opt/amina-travel
   ```

3. Pull latest changes:
   ```bash
   git pull origin main
   ```

4. Restart nginx container to apply new configuration:
   ```bash
   cd deploy
   docker restart amina-prod-nginx-1
   ```

5. Verify nginx started successfully:
   ```bash
   docker ps | grep nginx
   docker logs amina-prod-nginx-1 --tail 20
   ```

6. Test configuration is loaded:
   ```bash
   docker exec amina-prod-nginx-1 nginx -t
   ```

**Acceptance Criteria:**
- [ ] Git pull completes without conflicts
- [ ] Nginx container restarts successfully (shows "running" in docker ps)
- [ ] No errors in nginx logs after restart
- [ ] `nginx -t` shows "configuration file is ok" and "test is successful"
- [ ] Website and admin panels remain accessible
- [ ] API responds to health check requests

**Rollback Plan:**
If issues occur:
1. Revert nginx config changes: `git revert <commit-hash>`
2. Pull reverted changes: `git pull origin main`
3. Restart nginx: `docker restart amina-prod-nginx-1`

---

## Task 4: Test Availability Endpoint (Normal Speed) ⬜ NOT_STARTED

**Description:** Verify that availability requests completing in under 60 seconds still work correctly (regression test).

**Prerequisites:**
- Task 3 (deployment) must be completed

**API Information:**
- **Production API**: `https://api.aminatravel.org` (this is the REAL production API)
- **TunisiaBeds Backend**: `https://admin.tunisiabeds.tn/api/hotel` (external supplier API)
- **TunisiaBeds Docs**: `https://api-edocs.os-travel.com` (documentation reference only, not an API endpoint)

**Test Steps:**

1. Test single hotel availability (fast response expected):
   ```bash
   curl -X POST https://api.aminatravel.org/api/hotels/7752011d-b713-4796-a8c7-dd2d5e6cdfeb/availability \
     -H "Content-Type: application/json" \
     -d '{
       "checkIn": "2026-08-20",
       "checkOut": "2026-08-22",
       "rooms": [{"adults": 2, "children": []}]
     }' \
     -w "\nHTTP Status: %{http_code}\nTime: %{time_total}s\n"
   ```

2. Verify response:
   - Status code is 200 (not 502)
   - Response time is under 10 seconds
   - JSON body contains valid availability data or empty array
   - No "502 Bad Gateway" error

**Acceptance Criteria:**
- [ ] Request completes with HTTP 200 status
- [ ] Response time is reasonable (< 10 seconds)
- [ ] JSON response is valid and parsable
- [ ] Either availability data is returned OR empty result with `count: 0`
- [ ] No 502 errors occur

**Note:** This test uses the PRODUCTION API with REAL TunisiaBeds backend integration (credentials: XML_AminaTrv)

---

## Task 5: Test Availability Endpoint (Slow Response) ⬜ NOT_STARTED

**Description:** Verify that availability requests taking 60-120 seconds now complete successfully without 502 errors (bug fix verification).

**Prerequisites:**
- Task 3 (deployment) must be completed

**API Information:**
- **Testing PRODUCTION API**: `https://api.aminatravel.org` (REAL production environment)
- **Backend calls**: TunisiaBeds API at `https://admin.tunisiabeds.tn/api/hotel` (REAL supplier)
- **Warning**: This test hits the real TunisiaBeds backend and may take 60-120 seconds

**Test Steps:**

1. Test city-wide availability search (slow response expected - Sousse has 32 hotels):
   ```bash
   curl -X POST https://api.aminatravel.org/api/hotels/availability \
     -H "Content-Type: application/json" \
     -d '{
       "city": 34,
       "checkIn": "2026-08-20",
       "checkOut": "2026-08-22",
       "rooms": [{"adults": 2, "children": []}]
     }' \
     -w "\nHTTP Status: %{http_code}\nTime: %{time_total}s\n"
   ```

2. Monitor request:
   - Let it run for up to 2 minutes
   - Watch for 502 error at 60-second mark (should NOT occur)
   - Verify it completes successfully

3. Check response:
   - Status code is 200 (not 502)
   - Response time may be 60-120 seconds (this is expected)
   - JSON body contains hotel availability data

**Acceptance Criteria:**
- [ ] Request completes without 502 error (even if > 60 seconds)
- [ ] HTTP status is 200 or backend error (400, 500, 503) but NOT nginx 502
- [ ] If request takes 60-90 seconds, it still completes successfully
- [ ] JSON response is valid when it finally arrives
- [ ] No premature connection termination by nginx

**This is the PRIMARY test** - if this passes, the bug is fixed!

**Note:** This uses PRODUCTION API calling REAL TunisiaBeds backend (Login: XML_AminaTrv)

---

## Task 6: Regression Test Other API Endpoints ⬜ NOT_STARTED

**Description:** Verify that other API endpoints (non-availability) continue to work normally with unchanged timeout behavior.

**Prerequisites:**
- Task 3 (deployment) must be completed

**Test Steps:**

1. Test health/status endpoint:
   ```bash
   curl https://api.aminatravel.org/api/health
   ```

2. Test hotel search endpoint:
   ```bash
   curl "https://api.aminatravel.org/api/hotels/search?page=1&pageSize=12"
   ```

3. Test hotel cities endpoint:
   ```bash
   curl https://api.aminatravel.org/api/hotels/cities
   ```

4. Test featured hotels endpoint:
   ```bash
   curl "https://api.aminatravel.org/api/hotels/featured?limit=6"
   ```

5. Test hotel by slug:
   ```bash
   curl https://api.aminatravel.org/api/hotels/by-slug/movenpick-resort-marine-spa-sousse
   ```

**Acceptance Criteria:**
- [ ] All tested endpoints return HTTP 200
- [ ] Response times are normal (< 5 seconds)
- [ ] JSON responses are valid and contain expected data
- [ ] No 502 errors on any endpoint
- [ ] No performance degradation compared to before deployment

---

## Task 7: Regression Test Frontend Applications ⬜ NOT_STARTED

**Description:** Verify that the website and admin panel continue to load and function normally after nginx configuration changes.

**Prerequisites:**
- Task 3 (deployment) must be completed

**Test Steps:**

1. Test main website:
   - Open https://aminatravel.org in browser
   - Verify homepage loads completely
   - Navigate to hotels page
   - Click on a hotel detail page
   - Verify all images and content load

2. Test admin panel:
   - Open https://admin.aminatravel.org in browser
   - Verify login page loads
   - (Optional if you have credentials) Log in and verify dashboard loads

3. Test API subdomain directly:
   - Open https://api.aminatravel.org in browser
   - Should see API response or 404 (not 502 or connection error)

**Acceptance Criteria:**
- [ ] Website homepage loads without errors
- [ ] Hotel listing and detail pages function normally
- [ ] Admin panel login page loads
- [ ] No visible slowdown or timeout errors
- [ ] Browser console shows no new errors related to timeouts
- [ ] No 502 errors on any page

---

## Task 8: Monitor Production Logs ⬜ NOT_STARTED

**Description:** Monitor nginx access logs after deployment to verify the fix is working and track any remaining 502 errors.

**Prerequisites:**
- Task 3 (deployment) must be completed
- At least 1 hour has passed since deployment (to gather meaningful data)

**Monitoring Steps:**

1. SSH to production server:
   ```bash
   ssh -i ~/.ssh/amina_deploy_ed25519 root@162.35.185.169
   ```

2. Check nginx access logs for 502 errors:
   ```bash
   docker logs amina-prod-nginx-1 --tail 1000 | grep "502"
   ```

3. Count 502 errors on availability endpoints:
   ```bash
   docker logs amina-prod-nginx-1 --tail 1000 | grep -E "availability.*502" | wc -l
   ```

4. Check for successful availability requests > 60 seconds:
   ```bash
   docker logs amina-prod-nginx-1 --tail 1000 | grep "availability" | grep "200"
   ```

5. Monitor API container logs for TunisiaBeds timeouts:
   ```bash
   docker logs amina-prod-api-1 --tail 500 | grep -i "tunisia"
   ```

**Acceptance Criteria:**
- [ ] 502 errors on `/api/hotels/availability` endpoints are eliminated or significantly reduced
- [ ] Successful 200 responses appear for availability requests
- [ ] API logs show TunisiaBeds requests completing (even if slow)
- [ ] No new error patterns emerge after the change
- [ ] Request times in nginx logs show some requests taking 60-120 seconds (expected)

**Success Metric:** 
- Before: Availability requests frequently timeout with 502 after 60s
- After: Availability requests complete with 200 (or backend 500/503) even when > 60s

---

## Summary

**Total Tasks:** 8
**Current Status:** All NOT_STARTED

**Critical Path:**
1. Tasks 1-2: Configuration changes (can be done in parallel)
2. Task 3: Deploy (requires 1-2 complete)
3. Tasks 4-7: Testing (require 3 complete, can be done in parallel)
4. Task 8: Monitoring (requires 3 complete, wait 1 hour)

**Estimated Time:**
- Configuration: 30 minutes
- Deployment: 15 minutes
- Testing: 30 minutes
- Monitoring: 15 minutes (plus 1 hour wait time)
- **Total Active Work:** ~90 minutes

**Risk Level:** LOW
- Changes are isolated to nginx configuration
- Only affects API endpoint timeouts
- Easy rollback (revert + restart nginx)
- No code changes required
