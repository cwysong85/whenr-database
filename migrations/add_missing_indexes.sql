-- Add Missing Indexes for Optimal Query Performance
-- These indexes are CRITICAL for fast event search queries

-- ============================================================================
-- STEP 1: Core indexes on wc_events
-- ============================================================================

-- Index on start_at for date range filtering (VERY IMPORTANT)
CREATE INDEX IF NOT EXISTS idx_wc_events_start_at 
ON public.wc_events (start_at)
WHERE start_at IS NOT NULL;

COMMENT ON INDEX idx_wc_events_start_at IS 
  'Index for fast date range filtering on event start times';

-- Index on venue_id for joins (CRITICAL for performance)
CREATE INDEX IF NOT EXISTS idx_wc_events_venue_id 
ON public.wc_events (venue_id)
WHERE venue_id IS NOT NULL;

COMMENT ON INDEX idx_wc_events_venue_id IS 
  'Index for fast joins between events and venues';

-- Composite index for date + venue queries
CREATE INDEX IF NOT EXISTS idx_wc_events_start_venue 
ON public.wc_events (start_at, venue_id)
WHERE start_at IS NOT NULL AND venue_id IS NOT NULL;

COMMENT ON INDEX idx_wc_events_start_venue IS 
  'Composite index for queries filtering by both date and venue';

-- ============================================================================
-- STEP 2: Indexes on wc_offers for price queries
-- ============================================================================

-- Index on event_id for the CTE join
CREATE INDEX IF NOT EXISTS idx_wc_offers_event_id 
ON public.wc_offers (event_id);

-- Composite index for price filtering in CTE
CREATE INDEX IF NOT EXISTS idx_wc_offers_event_price 
ON public.wc_offers (event_id, price)
WHERE price IS NOT NULL;

COMMENT ON INDEX idx_wc_offers_event_price IS 
  'Index for fast price aggregation in event searches';

-- Index for currency lookup
CREATE INDEX IF NOT EXISTS idx_wc_offers_currency 
ON public.wc_offers (event_id, currency)
WHERE currency IS NOT NULL;

-- ============================================================================
-- STEP 3: Analyze tables to update query planner statistics
-- ============================================================================

ANALYZE public.wc_events;
ANALYZE public.wc_venues;
ANALYZE public.wc_offers;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check all indexes exist
SELECT 
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexname::regclass)) as index_size
FROM pg_indexes
WHERE tablename IN ('wc_events', 'wc_venues', 'wc_offers')
ORDER BY tablename, indexname;

-- Check row counts
SELECT 
  'wc_events' as table_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN start_at >= NOW() THEN 1 END) as future_events,
  COUNT(CASE WHEN venue_id IS NOT NULL THEN 1 END) as with_venue
FROM wc_events
UNION ALL
SELECT 
  'wc_venues',
  COUNT(*),
  COUNT(CASE WHEN location IS NOT NULL THEN 1 END),
  COUNT(CASE WHEN search_vector IS NOT NULL THEN 1 END)
FROM wc_venues
UNION ALL
SELECT 
  'wc_offers',
  COUNT(*),
  COUNT(CASE WHEN price IS NOT NULL THEN 1 END),
  COUNT(event_id)
FROM wc_offers;

-- ============================================================================
-- CRITICAL QUERY ORDER OPTIMIZATION
-- ============================================================================

-- The WHERE clause order matters! PostgreSQL usually processes them in order.
-- Optimal order (most selective filters first):
-- 1. Date range (e.start_at) - usually eliminates 80-90% of events
-- 2. Geographic location (v.location) - eliminates events outside radius
-- 3. Text search (search_vector) - matches remaining events by keywords
-- 4. Price filters - final refinement

-- Your current query should be reordered like this in the code:
-- WHERE 1=1
--   AND e.start_at >= $date_min
--   AND e.start_at <= $date_max
--   AND v.location IS NOT NULL
--   AND ST_DWithin(v.location, user_location, radius)
--   AND (e.search_vector @@ to_tsquery('english', $query) 
--        OR v.search_vector @@ to_tsquery('english', $query))
--   AND ep.price_min >= $price_min
--   AND ep.price_max <= $price_max

-- ============================================================================
-- SUCCESS!
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✓ Performance indexes created!';
  RAISE NOTICE '✓ Run EXPLAIN ANALYZE on your query';
  RAISE NOTICE '✓ Check that indexes are being used';
  RAISE NOTICE '========================================';
END $$;

