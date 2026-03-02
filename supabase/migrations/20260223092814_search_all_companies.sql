
DROP FUNCTION IF EXISTS search_companies_fuzzy(TEXT, INT);

CREATE OR REPLACE FUNCTION search_companies_fuzzy(
  search_query TEXT,
  result_limit INT DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  slug TEXT,
  company_name TEXT,
  yc_batch TEXT,
  one_liner TEXT,
  founders JSONB,
  categories TEXT[],
  founded_year INT,
  status TEXT,
  yc_url TEXT,
  location TEXT,
  website TEXT,
  team_size INT,
  launched_at BIGINT,
  last_synced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  search_vector TSVECTOR,
  similarity_score REAL
) AS $$
DECLARE
  query_lower TEXT := lower(search_query);
  old_threshold REAL;
BEGIN
  old_threshold := current_setting('pg_trgm.similarity_threshold')::REAL;
  PERFORM set_config('pg_trgm.similarity_threshold', '0.15', true);

  RETURN QUERY
  SELECT 
    c.id,
    c.slug,
    c.company_name,
    c.yc_batch,
    c.one_liner,
    c.founders,
    c.categories,
    c.founded_year,
    c.status,
    c.yc_url,
    c.location,
    c.website,
    c.team_size,
    c.launched_at,
    c.last_synced_at,
    c.created_at,
    c.search_vector,
    (
      CASE WHEN c.company_name ILIKE query_lower THEN 100.0 ELSE 0.0 END
      + CASE WHEN c.company_name ILIKE query_lower || '%' THEN 50.0 ELSE 0.0 END
      + CASE WHEN c.company_name ILIKE '%' || query_lower || '%' THEN 25.0 ELSE 0.0 END
      + CASE WHEN c.slug LIKE query_lower || '%' THEN 20.0 ELSE 0.0 END
      + CASE WHEN c.yc_batch ILIKE query_lower || '%' THEN 15.0 ELSE 0.0 END
      + similarity(c.company_name, search_query) * 15.0
      + similarity(c.slug, search_query) * 10.0
      + similarity(coalesce(c.one_liner, ''), search_query) * 5.0
    )::REAL AS similarity_score
  FROM companies c
  WHERE 
    c.company_name % search_query
    OR c.slug % search_query
    OR c.one_liner ILIKE '%' || query_lower || '%'
    OR c.yc_batch ILIKE '%' || query_lower || '%'
    OR c.company_name ILIKE '%' || query_lower || '%'
  ORDER BY 
    CASE WHEN c.status IN ('inactive', 'acquired') THEN 0 ELSE 1 END,
    similarity_score DESC, 
    c.company_name ASC
  LIMIT result_limit;

  PERFORM set_config('pg_trgm.similarity_threshold', old_threshold::TEXT, true);
END;
$$ LANGUAGE plpgsql;
;
