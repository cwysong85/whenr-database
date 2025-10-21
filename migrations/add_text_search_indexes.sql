-- Text Search Optimization for wc_events and wc_venues
-- This migration adds full-text search indexes for fast text queries
-- Uses PostgreSQL's built-in Full-Text Search (FTS) with GIN indexes

-- ============================================================================
-- STEP 1: Add tsvector columns for full-text search
-- ============================================================================

-- Add search vector to wc_events
ALTER TABLE public.wc_events 
ADD COLUMN IF NOT EXISTS search_vector tsvector;

COMMENT ON COLUMN public.wc_events.search_vector IS 
  'Full-text search vector combining title and description for fast text search';

-- Add search vector to wc_venues
ALTER TABLE public.wc_venues 
ADD COLUMN IF NOT EXISTS search_vector tsvector;

COMMENT ON COLUMN public.wc_venues.search_vector IS 
  'Full-text search vector for venue name for fast text search';

-- ============================================================================
-- STEP 2: Populate search vectors from existing data
-- ============================================================================

-- Update wc_events search vector
-- Combines title (weight A) and description (weight B)
-- Weight A = higher importance, Weight B = lower importance
UPDATE public.wc_events 
SET search_vector = 
  setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE(description, '')), 'B')
WHERE search_vector IS NULL;

-- Update wc_venues search vector
UPDATE public.wc_venues 
SET search_vector = to_tsvector('english', COALESCE(name, ''))
WHERE search_vector IS NULL;

-- Log progress
DO $$
DECLARE
  events_count INTEGER;
  venues_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO events_count 
  FROM public.wc_events 
  WHERE search_vector IS NOT NULL;
  
  SELECT COUNT(*) INTO venues_count
  FROM public.wc_venues
  WHERE search_vector IS NOT NULL;
  
  RAISE NOTICE '✓ Updated % events with search vectors', events_count;
  RAISE NOTICE '✓ Updated % venues with search vectors', venues_count;
END $$;

-- ============================================================================
-- STEP 3: Create GIN indexes for full-text search (CRITICAL!)
-- ============================================================================

-- GIN index on wc_events search_vector
CREATE INDEX IF NOT EXISTS idx_wc_events_search_vector 
ON public.wc_events 
USING GIN (search_vector);

COMMENT ON INDEX idx_wc_events_search_vector IS 
  'GIN index for fast full-text search on event titles and descriptions';

-- GIN index on wc_venues search_vector  
CREATE INDEX IF NOT EXISTS idx_wc_venues_search_vector 
ON public.wc_venues 
USING GIN (search_vector);

COMMENT ON INDEX idx_wc_venues_search_vector IS 
  'GIN index for fast full-text search on venue names';

-- ============================================================================
-- STEP 4: Add trigram indexes for LIKE queries (optional, for backward compat)
-- ============================================================================

-- Enable pg_trgm extension for trigram matching
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public;

-- Trigram indexes for case-insensitive LIKE queries
-- These help with queries like: WHERE LOWER(title) LIKE LOWER('%search%')

CREATE INDEX IF NOT EXISTS idx_wc_events_title_trgm 
ON public.wc_events 
USING GIN (LOWER(title) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_wc_events_description_trgm 
ON public.wc_events 
USING GIN (LOWER(description) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_wc_venues_name_trgm 
ON public.wc_venues 
USING GIN (LOWER(name) gin_trgm_ops);

-- ============================================================================
-- STEP 5: Create triggers to auto-update search vectors
-- ============================================================================

-- Function to update wc_events search vector
CREATE OR REPLACE FUNCTION update_event_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update wc_venues search vector
CREATE OR REPLACE FUNCTION update_venue_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := to_tsvector('english', COALESCE(NEW.name, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for wc_events
DROP TRIGGER IF EXISTS trigger_update_event_search_vector ON public.wc_events;
CREATE TRIGGER trigger_update_event_search_vector
BEFORE INSERT OR UPDATE OF title, description ON public.wc_events
FOR EACH ROW
EXECUTE FUNCTION update_event_search_vector();

-- Trigger for wc_venues
DROP TRIGGER IF EXISTS trigger_update_venue_search_vector ON public.wc_venues;
CREATE TRIGGER trigger_update_venue_search_vector
BEFORE INSERT OR UPDATE OF name ON public.wc_venues
FOR EACH ROW
EXECUTE FUNCTION update_venue_search_vector();

-- ============================================================================
-- STEP 6: Analyze tables to update statistics
-- ============================================================================

ANALYZE public.wc_events;
ANALYZE public.wc_venues;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check search vectors are populated
SELECT 
  'wc_events' as table_name,
  COUNT(*) as total,
  COUNT(search_vector) as with_search_vector,
  COUNT(search_vector) * 100.0 / COUNT(*) as percentage
FROM public.wc_events
UNION ALL
SELECT 
  'wc_venues' as table_name,
  COUNT(*) as total,
  COUNT(search_vector) as with_search_vector,
  COUNT(search_vector) * 100.0 / COUNT(*) as percentage
FROM public.wc_venues;

-- Verify indexes exist
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE indexname LIKE '%search%' OR indexname LIKE '%trgm%'
ORDER BY tablename, indexname;

-- Test full-text search (concerts example)
SELECT 
  id,
  title,
  ts_rank(search_vector, to_tsquery('english', 'concerts')) as rank
FROM public.wc_events
WHERE search_vector @@ to_tsquery('english', 'concerts')
ORDER BY rank DESC
LIMIT 10;

-- Test trigram search (for LIKE compatibility)
SELECT 
  id,
  title,
  similarity(LOWER(title), 'concert') as similarity_score
FROM public.wc_events
WHERE LOWER(title) LIKE LOWER('%concert%')
ORDER BY similarity_score DESC
LIMIT 10;

-- ============================================================================
-- SUCCESS!
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✓ Text search optimization completed!';
  RAISE NOTICE '✓ Full-text search vectors added';
  RAISE NOTICE '✓ GIN indexes created';
  RAISE NOTICE '✓ Trigram indexes created';
  RAISE NOTICE '✓ Auto-update triggers installed';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Next: Update backend code to use ts_query';
  RAISE NOTICE 'or keep using LIKE (now indexed)';
END $$;

