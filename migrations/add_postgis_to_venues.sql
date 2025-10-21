-- PostGIS Migration for wc_venues table
-- This migration adds geography column and spatial index for optimized location queries
--
-- IMPORTANT: This migration includes ::numeric casts because lat/lon columns
-- are double precision (float) type. ST_MakePoint prefers numeric type.
-- The casts ensure compatibility: ST_MakePoint(lon::numeric, lat::numeric)

-- ============================================================================
-- PREREQUISITE: Ensure PostGIS extension is enabled in public schema
-- ============================================================================

-- Enable PostGIS extension if not already enabled (run in public schema)
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;

-- Verify PostGIS is available
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'geography'
  ) THEN
    RAISE EXCEPTION 'PostGIS extension not properly installed. Run: CREATE EXTENSION postgis;';
  END IF;
  RAISE NOTICE '✓ PostGIS extension is available';
END $$;

-- ============================================================================
-- STEP 1: Add geography column
-- ============================================================================

ALTER TABLE public.wc_venues 
ADD COLUMN IF NOT EXISTS location public.geography(POINT, 4326);

COMMENT ON COLUMN public.wc_venues.location IS 
  'PostGIS geography point for efficient spatial queries. Auto-populated from lat/lon.';

-- ============================================================================
-- STEP 2: Populate geography column from existing lat/lon data
-- ============================================================================

-- Cast float columns to numeric for ST_MakePoint
UPDATE public.wc_venues 
SET location = ST_SetSRID(
  ST_MakePoint(lon::numeric, lat::numeric), 
  4326
)::geography
WHERE lat IS NOT NULL 
  AND lon IS NOT NULL
  AND location IS NULL;

-- Log how many rows were updated
DO $$
DECLARE
  row_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO row_count 
  FROM public.wc_venues 
  WHERE location IS NOT NULL;
  
  RAISE NOTICE 'Updated % venues with geography locations', row_count;
END $$;

-- ============================================================================
-- STEP 3: Create spatial index (CRITICAL for performance)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_wc_venues_location 
ON public.wc_venues 
USING GIST (location);

COMMENT ON INDEX idx_wc_venues_location IS 
  'Spatial index for fast distance queries using PostGIS';

-- ============================================================================
-- STEP 4: Create trigger to auto-update geography on lat/lon changes
-- ============================================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_venue_location ON public.wc_venues;
DROP FUNCTION IF EXISTS update_venue_location();

-- Create function with explicit type casting
CREATE OR REPLACE FUNCTION update_venue_location()
RETURNS TRIGGER AS $$
BEGIN
  -- Update location when lat/lon is set
  IF NEW.lat IS NOT NULL AND NEW.lon IS NOT NULL THEN
    -- Cast to numeric for ST_MakePoint compatibility
    NEW.location := ST_SetSRID(
      ST_MakePoint(NEW.lon::numeric, NEW.lat::numeric), 
      4326
    )::geography;
  ELSE
    NEW.location := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_venue_location() IS 
  'Automatically updates geography location column when lat/lon changes';

-- Create trigger
CREATE TRIGGER trigger_update_venue_location
BEFORE INSERT OR UPDATE OF lat, lon ON public.wc_venues
FOR EACH ROW
EXECUTE FUNCTION update_venue_location();

-- ============================================================================
-- STEP 5: Analyze table to update statistics
-- ============================================================================

ANALYZE public.wc_venues;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check venues with location
SELECT 
  COUNT(*) as total_venues,
  COUNT(location) as venues_with_location,
  COUNT(location) * 100.0 / COUNT(*) as percentage_complete
FROM public.wc_venues;

-- Verify index exists
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'wc_venues' 
  AND indexname = 'idx_wc_venues_location';

-- Test distance query (Indianapolis coordinates as example)
SELECT 
  id,
  name,
  lat,
  lon,
  ST_Distance(
    location,
    ST_SetSRID(ST_MakePoint(-86.1581::numeric, 39.7684::numeric), 4326)::geography
  ) / 1609.34 as distance_miles
FROM public.wc_venues
WHERE location IS NOT NULL
  AND ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(-86.1581::numeric, 39.7684::numeric), 4326)::geography,
    40234  -- 25 miles in meters
  )
ORDER BY distance_miles
LIMIT 5;

-- ============================================================================
-- SUCCESS!
-- ============================================================================

RAISE NOTICE '✓ PostGIS migration completed successfully!';
RAISE NOTICE '✓ Geography column added to wc_venues';
RAISE NOTICE '✓ Spatial index created';
RAISE NOTICE '✓ Auto-update trigger installed';
RAISE NOTICE 'Next: Update backend code to use PostGIS queries';

