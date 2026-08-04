# Bugfix Requirements Document

## Introduction

The hotel availability endpoint (`POST /api/hotels/{id}/availability` and `POST /api/hotels/availability`) returns **502 Bad Gateway** errors when calling the TunisiaBeds supplier API. The issue affects all availability searches and prevents users from checking hotel room availability and pricing.

**Root Cause Analysis:**
- **TunisiaBeds API is slow**: Response times are 4+ seconds per request
- **Nginx proxy timeout**: Default `proxy_read_timeout` is 60 seconds
- **Backend HttpClient timeout**: Set to 120 seconds (higher than nginx)
- **Request flow**: Browser → Cloudflare (100s timeout) → Nginx (60s timeout) → ASP.NET Core API (120s timeout) → TunisiaBeds API (slow)

When TunisiaBeds takes longer than 60 seconds to respond, nginx closes the connection and returns 502 Bad Gateway to the client, even though the backend has a higher timeout configured.

**Impact:**
- Availability endpoint is completely broken
- Users cannot search for hotels or check prices
- Booking flow is blocked at the first step

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a user calls `/api/hotels/{id}/availability` or `/api/hotels/availability` AND TunisiaBeds response time exceeds 60 seconds THEN nginx returns 502 Bad Gateway error

1.2 WHEN nginx proxy_read_timeout (60s default) is lower than backend HttpClient timeout (120s) THEN the proxy layer terminates the request before the backend completes

1.3 WHEN multiple availability searches are performed in sequence AND each takes 4+ seconds THEN the cumulative time can exceed nginx timeout causing 502 errors

1.4 WHEN nginx timeout occurs THEN the user sees "502 Bad Gateway" with no meaningful error message

### Expected Behavior (Correct)

2.1 WHEN a user calls `/api/hotels/{id}/availability` or `/api/hotels/availability` AND TunisiaBeds takes up to 120 seconds to respond THEN the request SHALL complete successfully without timeout

2.2 WHEN nginx is configured with `proxy_read_timeout` AND `proxy_connect_timeout` THEN these values SHALL be at least 130 seconds (10 seconds buffer above backend timeout)

2.3 WHEN TunisiaBeds API is slow (4+ seconds per city search) THEN the system SHALL wait for the full response without premature termination

2.4 WHEN an availability search completes successfully THEN the system SHALL return valid JSON with hotel availability data or an empty result (not 502 error)

### Unchanged Behavior (Regression Prevention)

3.1 WHEN TunisiaBeds responds within 60 seconds THEN the system SHALL CONTINUE TO return results as it does currently

3.2 WHEN TunisiaBeds returns an error response (400, 401, 403, 500, 503) THEN the backend SHALL CONTINUE TO handle it with retry logic and proper error mapping

3.3 WHEN TunisiaBeds returns empty availability (no hotels available) THEN the system SHALL CONTINUE TO return a valid response with `count: 0` and empty `hotels` array

3.4 WHEN other API endpoints are called (not availability) THEN they SHALL CONTINUE TO work with existing timeout configurations

3.5 WHEN nginx proxies requests to the website or admin frontend THEN those timeouts SHALL CONTINUE TO use their existing values (not affected by this fix)

---

## Bug Condition (Derived)

The bug condition can be expressed in structured pseudocode:

```pascal
FUNCTION isBugCondition(request)
  INPUT: request of type HttpRequest
  OUTPUT: boolean
  
  // Bug occurs when:
  // 1. Request is to availability endpoint
  // 2. TunisiaBeds response time > nginx timeout (60s)
  // 3. But < backend timeout (120s)
  
  RETURN (
    (request.path = "/api/hotels/availability" OR 
     request.path MATCHES "/api/hotels/{guid}/availability") AND
    tunisiaBedsResponseTime > 60 seconds AND
    tunisiaBedsResponseTime < 120 seconds
  )
END FUNCTION
```

### Fix Checking Property

```pascal
// Property: Availability requests SHALL NOT timeout before backend timeout
FOR ALL requests WHERE isBugCondition(request) DO
  result ← processAvailabilityRequest'(request)
  ASSERT result.statusCode != 502 AND
         result.completed = true AND
         (result.statusCode = 200 OR result.statusCode IN [400, 500, 503])
END FOR
```

**Key Definitions:**
- **F**: Original nginx configuration with default 60s timeout
- **F'**: Fixed nginx configuration with 130s timeout

### Preservation Checking Property

```pascal
// Property: Non-availability requests SHALL behave identically
FOR ALL requests WHERE NOT isBugCondition(request) DO
  ASSERT F(request) = F'(request)
END FOR
```

This ensures that changing nginx timeout for API endpoints does not affect:
- Other API endpoints (auth, bookings, payments, etc.)
- Frontend proxying (website, admin)
- Static file serving
- Health checks

---

## Concrete Counterexample

**Test Case:**
1. Call `POST https://api.aminatravel.org/api/hotels/7752011d-b713-4796-a8c7-dd2d5e6cdfeb/availability`
2. With payload:
   ```json
   {
     "checkIn": "2026-08-16",
     "checkOut": "2026-08-18",
     "rooms": [{"adults": 2, "children": []}]
   }
   ```
3. TunisiaBeds search takes 65 seconds (above nginx default but below backend timeout)

**Current Result:** 502 Bad Gateway after 60 seconds  
**Expected Result:** 200 OK with availability data after 65 seconds

---

## Solution Requirements

### Configuration Changes Required

1. **Nginx Timeout Configuration** (HIGH PRIORITY)
   - Update `deploy/nginx/templates/amina.conf.template`
   - Update `deploy/nginx/templates/tls.conf.template`
   - Add `proxy_read_timeout 130s;` to API location block
   - Add `proxy_connect_timeout 130s;` to API location block
   - Add `proxy_send_timeout 130s;` to API location block

2. **Documentation Updates**
   - Document the timeout hierarchy in code comments
   - Update DEPLOY.md with timeout architecture explanation

### Why 130 seconds?

**Timeout Hierarchy:**
1. **Cloudflare Free Tier**: 100 seconds (cannot be changed)
2. **Backend HttpClient**: 120 seconds (configured in `HotelsModule.cs`)
3. **Nginx Proxy**: 130 seconds (10-second buffer above backend)

The nginx timeout must be higher than the backend timeout to allow the backend to complete its work and return a proper error response if TunisiaBeds times out at 120s.

### Out of Scope

- Changing TunisiaBeds API response time (external dependency)
- Optimizing backend retry logic (separate performance improvement)
- Implementing caching (separate feature)
- Changing Cloudflare timeout (requires paid plan)

---

## Testing Strategy

### Manual Testing

1. **Single Hotel Availability** (normal speed):
   - Call `/api/hotels/{id}/availability` for a hotel that responds in < 5 seconds
   - Verify: 200 OK with availability data

2. **City-Wide Availability** (slow):
   - Call `/api/hotels/availability` for Sousse (32 hotels)
   - Verify: Completes without 502 error (may take 60-90 seconds)

3. **Timeout at Backend Level**:
   - If possible, simulate a 125-second TunisiaBeds delay
   - Verify: Backend returns 502 (from TunisiaBeds timeout), NOT nginx 502

### Regression Testing

1. **Other API Endpoints**:
   - Test auth login, booking creation, payment endpoints
   - Verify: All work as before (no timeout changes)

2. **Frontend Proxying**:
   - Load website and admin pages
   - Verify: No performance degradation

### Load Testing (Optional)

- Multiple concurrent availability requests
- Verify: No cascading failures or resource exhaustion

---

## Notes for Implementation

1. **Deployment**: Nginx configuration changes require container restart (`docker compose restart nginx`)

2. **Monitoring**: After deployment, monitor nginx access logs for:
   - Reduction in 502 errors on availability endpoints
   - Successful completion of requests > 60 seconds

3. **Rollback Plan**: If issues occur, revert nginx config and restart container

4. **Future Optimization**: Consider implementing:
   - Response caching for recent availability searches
   - Rate limiting to prevent TunisiaBeds overload
   - Async job queue for slow searches with polling endpoint
