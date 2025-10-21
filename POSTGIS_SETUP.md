# PostGIS Setup Guide for Supabase

This guide walks you through setting up PostGIS for optimized location-based queries in your Whenr database.

## Current Setup

- ✅ PostGIS extension enabled
- ✅ `gis` schema created
- Table: `wc_venues` with `lat` (double) and `lon` (double) columns
- Current implementation: Haversine formula (slow for large datasets)

## Why PostGIS?

PostGIS provides:

- **Faster queries**: Native spatial indexes (GiST) vs calculating Haversine on every row
- **Better scalability**: O(log n) lookups vs O(n) calculations
- **More features**: Distance, containment, nearest neighbor queries
- **Standards-based**: Uses standard geography/geometry types

## Step-by-Step Setup

### Step 1: Add Geography Column to wc_venues

Run this SQL in Supabase SQL Editor:

```sql
-- Add a geography column (uses SRID 4326 - WGS84)
-- Geography type automatically handles earth curvature
ALTER TABLE public.wc_venues
ADD COLUMN IF NOT EXISTS location geography(POINT, 4326);
```

**What this does:**

- Creates a new column `location` of type `geography(POINT, 4326)`
- `POINT` = stores a single coordinate pair
- `4326` = SRID for WGS84 (standard GPS coordinates)
- `geography` = uses spherical calculations (accurate for Earth)

### Step 2: Populate Geography Column from Existing Data

```sql
-- Update all existing venues to populate geography column
UPDATE public.wc_venues
SET location = ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
WHERE lat IS NOT NULL
  AND lon IS NOT NULL
  AND location IS NULL;

-- Check how many rows were updated
SELECT COUNT(*) as venues_with_location
FROM public.wc_venues
WHERE location IS NOT NULL;
```

**What this does:**

- `ST_MakePoint(lon, lat)` creates a point geometry (note: lon first, then lat)
- `ST_SetSRID(..., 4326)` sets the coordinate system
- `::geography` casts to geography type for spherical calculations
- Updates only rows that have lat/lon but no location yet

### Step 3: Create Spatial Index (CRITICAL for Performance)

```sql
-- Create GIST index on geography column
-- This is what makes location queries fast!
CREATE INDEX IF NOT EXISTS idx_wc_venues_location
ON public.wc_venues
USING GIST (location);

-- Verify index was created
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'wc_venues'
  AND indexname = 'idx_wc_venues_location';
```

**What this does:**

- Creates a GIST (Generalized Search Tree) index
- Enables efficient spatial queries
- Dramatically improves query performance (100x+ for large datasets)

### Step 4: Add Trigger to Auto-Update Geography Column

```sql
-- Create function to automatically update geography when lat/lon changes
CREATE OR REPLACE FUNCTION update_venue_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lon IS NOT NULL THEN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326)::geography;
  ELSE
    NEW.location := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on INSERT and UPDATE
DROP TRIGGER IF EXISTS trigger_update_venue_location ON public.wc_venues;
CREATE TRIGGER trigger_update_venue_location
BEFORE INSERT OR UPDATE OF lat, lon ON public.wc_venues
FOR EACH ROW
EXECUTE FUNCTION update_venue_location();
```

**What this does:**

- Automatically syncs `location` with `lat`/`lon` changes
- Runs before INSERT or UPDATE
- Keeps data consistent without manual updates

### Step 5: Verify Setup

```sql
-- Check that everything is working
SELECT
  id,
  name,
  lat,
  lon,
  location,
  ST_AsText(location::geometry) as location_text
FROM public.wc_venues
WHERE location IS NOT NULL
LIMIT 5;

-- Test a distance query (from Indianapolis: 39.7684, -86.1581)
SELECT
  id,
  name,
  lat,
  lon,
  ST_Distance(
    location,
    ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography
  ) / 1609.34 as distance_miles
FROM public.wc_venues
WHERE location IS NOT NULL
  AND ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography,
    40234 -- 25 miles in meters
  )
ORDER BY distance_miles
LIMIT 10;
```

## Step 6: Update Backend Code

Now update your `eventService.ts` to use PostGIS instead of Haversine:

### Replace the Geographic Filtering Section

**Find this code (around line 534):**

```typescript
// Geographic filtering (if near location provided)
if (geoLocation) {
  // Using Haversine formula to filter within radius
  sqlQuery += `
    AND v.lat IS NOT NULL 
    AND v.lon IS NOT NULL
    AND (
      3959 * acos(
        cos(radians($${paramIndex})) * cos(radians(v.lat)) * 
        cos(radians(v.lon) - radians($${paramIndex + 1})) + 
        sin(radians($${paramIndex})) * sin(radians(v.lat))
      )
    ) <= $${paramIndex + 2}
  `;
  queryParams.push(geoLocation.lat, geoLocation.lon, radiusMiles);
  paramIndex += 3;
}
```

**Replace with PostGIS version:**

```typescript
// Geographic filtering using PostGIS
if (geoLocation) {
  // Convert miles to meters for ST_DWithin (1 mile = 1609.34 meters)
  const radiusMeters = radiusMiles * 1609.34;

  sqlQuery += `
    AND v.location IS NOT NULL
    AND ST_DWithin(
      v.location,
      ST_SetSRID(ST_MakePoint($${
        paramIndex + 1
      }, $${paramIndex}), 4326)::geography,
      $${paramIndex + 2}
    )
  `;
  queryParams.push(geoLocation.lat, geoLocation.lon, radiusMeters);
  paramIndex += 3;
}
```

### Update Distance Calculation in SELECT

**Find (around line 479):**

```typescript
${geoLocation ? `, v.lat as calc_lat, v.lon as calc_lon` : ""}
```

**Replace with:**

```typescript
${geoLocation ? `,
  ST_Distance(
    v.location,
    ST_SetSRID(ST_MakePoint($lon_param, $lat_param), 4326)::geography
  ) / 1609.34 as distance_miles
` : ""}
```

**Or update the distance calculation in the result mapping:**

After the query results, update the distance calculation from Haversine to use the database value:

```typescript
// In the results mapping (around line 630-640)
distanceMiles: geoLocation && row.venue_lat && row.venue_lon
  ? // Use calculated distance from query instead of recalculating
    parseFloat(row.distance_miles)
  : undefined,
```

### Update Sorting

**Find:**

```typescript
// Sorting
let orderBy = "";
if (sort === "date") {
  orderBy = "ORDER BY e.start_at ASC";
} else if (sort === "distance" && geoLocation) {
  orderBy = `ORDER BY (
    3959 * acos(
      cos(radians(${geoLocation.lat})) * cos(radians(v.lat)) * 
      cos(radians(v.lon) - radians(${geoLocation.lon})) + 
      sin(radians(${geoLocation.lat})) * sin(radians(v.lat))
    )
  ) ASC`;
} else {
  // Default: relevance sort (text match first, then by date)
  orderBy = q ? "ORDER BY e.start_at DESC" : "ORDER BY e.start_at DESC";
}
```

**Replace with:**

```typescript
// Sorting
let orderBy = "";
if (sort === "date") {
  orderBy = "ORDER BY e.start_at ASC";
} else if (sort === "distance" && geoLocation) {
  orderBy = `ORDER BY ST_Distance(
    v.location,
    ST_SetSRID(ST_MakePoint(${geoLocation.lon}, ${geoLocation.lat}), 4326)::geography
  ) ASC`;
} else {
  // Default: relevance sort (text match first, then by date)
  orderBy = q ? "ORDER BY e.start_at DESC" : "ORDER BY e.start_at DESC";
}
```

## Testing PostGIS Setup

### Test Query Performance

```sql
-- Test query with EXPLAIN ANALYZE to see performance
EXPLAIN ANALYZE
SELECT
  id,
  name,
  ST_Distance(
    location,
    ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography
  ) / 1609.34 as distance_miles
FROM public.wc_venues
WHERE location IS NOT NULL
  AND ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography,
    40234  -- 25 miles in meters
  )
ORDER BY distance_miles
LIMIT 20;
```

**Look for:**

- "Index Scan using idx_wc_venues_location" = ✅ Good!
- "Seq Scan on wc_venues" = ❌ Index not being used

### Check Index Usage

```sql
-- See if your index is being used
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename = 'wc_venues';
```

## Benefits You'll See

### Performance Comparison

**Before (Haversine):**

- Full table scan on every query
- Calculates distance for every venue
- 10,000 venues ≈ 500-1000ms
- 100,000 venues ≈ 5-10 seconds

**After (PostGIS with GIST index):**

- Index-based lookup
- Only calculates distance for nearby venues
- 10,000 venues ≈ 10-50ms
- 100,000 venues ≈ 20-100ms

**~10-100x faster!** 🚀

## Common PostGIS Functions

### Distance Queries

```sql
-- Distance in meters
ST_Distance(location1, location2)

-- Distance in miles (divide by 1609.34)
ST_Distance(location1, location2) / 1609.34

-- Within radius (faster than calculating distance)
ST_DWithin(location, center_point, radius_meters)
```

### Finding Nearby Items

```sql
-- Find venues within 25 miles of a point
SELECT * FROM wc_venues
WHERE ST_DWithin(
  location,
  ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography,
  40234  -- 25 miles = 40,234 meters
)
ORDER BY ST_Distance(
  location,
  ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography
);
```

### K-Nearest Neighbors

```sql
-- Find 10 closest venues (uses index!)
SELECT
  *,
  ST_Distance(
    location,
    ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography
  ) / 1609.34 as distance_miles
FROM wc_venues
WHERE location IS NOT NULL
ORDER BY location <-> ST_SetSRID(ST_MakePoint(-86.1581, 39.7684), 4326)::geography
LIMIT 10;
```

Note: The `<->` operator is the KNN (K-nearest neighbor) operator - super fast!

## Troubleshooting

### Index Not Being Used?

```sql
-- Force index usage with high work_mem
SET work_mem = '256MB';

-- Analyze table to update statistics
ANALYZE wc_venues;

-- Check if statistics are up to date
SELECT
  schemaname,
  tablename,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE tablename = 'wc_venues';
```

### NULL Locations?

```sql
-- Find venues without geography
SELECT COUNT(*) as missing_location
FROM wc_venues
WHERE location IS NULL
  AND (lat IS NOT NULL OR lon IS NOT NULL);

-- Fix them
UPDATE wc_venues
SET location = ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
WHERE location IS NULL
  AND lat IS NOT NULL
  AND lon IS NOT NULL;
```

## Migration Checklist

- [ ] Step 1: Add geography column to wc_venues
- [ ] Step 2: Populate geography from lat/lon
- [ ] Step 3: Create GIST index
- [ ] Step 4: Add trigger for auto-updates
- [ ] Step 5: Verify with test queries
- [ ] Step 6: Update eventService.ts code
- [ ] Step 7: Test API endpoint performance
- [ ] Step 8: Monitor query performance in production

## Additional Optimizations

### Partial Index for Active Venues

If you have many venues but only some are active:

```sql
CREATE INDEX idx_wc_venues_location_active
ON wc_venues USING GIST (location)
WHERE is_active = true;  -- Adjust field name as needed
```

### Covering Index

If you frequently need distance + other fields:

```sql
CREATE INDEX idx_wc_venues_location_with_name
ON wc_venues USING GIST (location)
INCLUDE (name, street_address);
```

## Resources

- [PostGIS Distance Functions](https://postgis.net/docs/reference.html#Distance_Relationships)
- [PostGIS Performance Tips](https://postgis.net/docs/performance_tips.html)
- [Supabase PostGIS Guide](https://supabase.com/docs/guides/database/extensions/postgis)

## Notes

- Always use `geography` type (not `geometry`) for GPS coordinates
- SRID 4326 is WGS84 (standard GPS coordinate system)
- `ST_DWithin` is faster than calculating distance for filtering
- Use KNN operator `<->` for nearest neighbor queries
- Distance in geography is in meters by default (divide by 1609.34 for miles)
