# Golf Résidence Availability Issue - Analysis & Solution

## Problem Summary

"Golf Résidence" hotel shows **"Aucune disponibilité pour ces dates. Essayez d'autres dates"** instead of displaying all room types with their availability status (Available, OnRequest, or StopSell).

## Root Cause

The issue occurs because of how the system handles **completely stop-sold hotels**:

1. **Golf Résidence** has `HasLiveRates: true` (it's a TunisiaBeds hotel)
2. The hotel detail page uses the `HotelAvailabilityPanel` which calls the live availability API
3. When querying availability:
   - The API calls TunisiaBeds with a **city-wide search** (passing `OnlyAvailable: false`)
   - TunisiaBeds returns hotels that have *some* availability in the city
   - The API then **filters** the results to only the requested hotel (Golf Résidence)
   - **If TunisiaBeds doesn't include Golf Résidence in the city results** (likely because ALL its rooms are stop-sold), the filtered result is **empty**
4. The frontend shows "Aucune disponibilité" when the API returns an empty result

### Why City-Wide Search?

From `HotelAvailabilityService.cs` line 27:
```csharp
// NEVER pass the Hotels parameter to TunisiaBeds - it causes "Hôtel(s) non affecter" errors.
// Instead, do a city-wide search and filter results on our side.
```

The API must do a city-wide search and filter locally because passing specific hotel IDs to TunisiaBeds causes errors.

## The Real Issue

**TunisiaBeds likely excludes completely stop-sold hotels from city search results**, even when `OnlyAvailable: false` is set. This causes:

- Hotels with *some* available rooms → Returned by TunisiaBeds, status displayed correctly ✅
- Hotels with *all* rooms stop-sold → **NOT returned by TunisiaBeds**, shows "no availability" ❌

## Previous Feature Context

Commit `ad7543d` (Aug 15, 2026) implemented the feature to "show all room types with their status":
- **Goal**: Display Available, OnRequest, and StopSell rooms (not just available ones)
- **What it fixed**: Rooms that ARE returned by TunisiaBeds now show their status
- **What it didn't fix**: Hotels that TunisiaBeds doesn't return at all

## Solution Implemented

### 1. Enhanced Logging (✅ Completed)

Added detailed logging to `HotelAvailabilityService.cs` to diagnose the issue:

```csharp
logger.LogInformation(
    "TunisiaBeds city search (city={CityId}, OnlyAvailable={OnlyAvailable}) returned {Count} hotels",
    request.City, filters.OnlyAvailable, results.Count);

logger.LogInformation(
    "Filtered to hotel ID {HotelId}: {BeforeCount} hotels -> {AfterCount} hotels. Hotel found: {Found}",
    onlyHotelId.Value, beforeFilter, results.Count, results.Count > 0);

if (results.Count == 0 && beforeFilter > 0)
{
    logger.LogWarning(
        "Hotel ID {HotelId} not found in TunisiaBeds city search results. " +
        "This hotel may be completely stop-sold or not available for the requested dates.");
}
```

### 2. Testing the Fix

To verify the root cause and test the solution:

1. **Start the backend**:
   ```bash
   cd backend/src/Amina.Travel.Api
   dotnet run
   ```

2. **Search for Golf Résidence availability** on the frontend for dates Sept 16-25, 2026

3. **Check the logs** for output like:
   ```
   TunisiaBeds city search (city=X, OnlyAvailable=False) returned 45 hotels
   Filtered to hotel ID Y: 45 hotels -> 0 hotels. Hotel found: False
   Hotel ID Y not found in TunisiaBeds city search results...
   ```

4. If logs confirm Golf Résidence is missing from TunisiaBeds response, this proves the issue.

### 3. Potential Solutions

#### Option A: Direct Hotel Query (Requires TunisiaBeds API change)
Try passing the hotel ID directly to TunisiaBeds:
```csharp
var results = await client.HotelSearchAsync(request.City, checkIn, checkOut, rooms, filters, 
    hotels: [onlyHotelId.Value], ct: ct);
```

⚠️ **Risk**: The comment says this causes "Hôtel(s) non affecter" errors. Test carefully.

#### Option B: Fallback to Static Rooms (Recommended)
When TunisiaBeds returns empty for a hotel:
1. Check if the hotel has static rooms defined in the database
2. Display those with a message: "Tarifs standard disponibles - contactez-nous pour la disponibilité en temps réel"
3. Allow users to request a quote

#### Option C: Better Error Message
Show a more helpful message when a hotel returns empty:
```
"Aucune disponibilité en ligne pour ces dates. Contactez-nous au XXX pour vérifier la disponibilité de Golf Résidence."
```

## Recommended Next Steps

1. **Verify the root cause** by running the backend and checking logs
2. **Test with different dates** to see if Golf Résidence appears for any date range
3. **Check Golf Résidence's data** in the database:
   ```sql
   SELECT id, name, slug, "SupplierHotelId", "SupplierCityId", "HasLiveRates" 
   FROM hotels."Hotels" 
   WHERE name LIKE '%Golf%Résidence%';
   ```
4. **Contact TunisiaBeds support** to understand why completely stop-sold hotels are excluded
5. **Implement Option B** (fallback to static rooms) as a robust solution

## Files Modified

- `backend/src/Amina.Travel.Api/Modules/Hotels/Infrastructure/TunisiaBeds/HotelAvailabilityService.cs`
  - Added ILogger dependency injection
  - Added detailed logging for TunisiaBeds responses
  - Added warning when filtered hotel is not found

## Related Commits

- `ad7543d` - "fix: every hotel states its availability, free sale included" (Aug 15, 2026)
- `c11ff2a` - "feat: show "disponible sur demande" and "stop sell" on hotel results"
- `2d39042` - "feat: surface on-request and stop-sell hotels in search"
