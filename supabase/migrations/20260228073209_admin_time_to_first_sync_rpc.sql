
-- Time to first sync: distribution of how long until users first push data
CREATE OR REPLACE FUNCTION admin_time_to_first_sync()
RETURNS TABLE (
  bucket text,
  bucket_order int,
  user_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH real_users AS (
    SELECT id, created_at
    FROM users
    WHERE id::text NOT LIKE 'a0000000-0000-4000-8000-%'
  ),
  first_sync AS (
    SELECT
      du.user_id,
      MIN(du.created_at) AS first_sync_at
    FROM daily_usage du
    JOIN real_users ru ON du.user_id = ru.id
    GROUP BY du.user_id
  ),
  activation AS (
    SELECT
      ru.id AS user_id,
      EXTRACT(EPOCH FROM (fs.first_sync_at - ru.created_at)) / 3600.0 AS hours_to_sync
    FROM real_users ru
    LEFT JOIN first_sync fs ON ru.id = fs.user_id
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN hours_to_sync IS NULL THEN 'Never'
        WHEN hours_to_sync < 1 THEN '< 1 hour'
        WHEN hours_to_sync < 24 THEN '1-24 hours'
        WHEN hours_to_sync < 72 THEN '1-3 days'
        WHEN hours_to_sync < 168 THEN '3-7 days'
        ELSE '7+ days'
      END AS bucket,
      CASE
        WHEN hours_to_sync IS NULL THEN 6
        WHEN hours_to_sync < 1 THEN 1
        WHEN hours_to_sync < 24 THEN 2
        WHEN hours_to_sync < 72 THEN 3
        WHEN hours_to_sync < 168 THEN 4
        ELSE 5
      END AS bucket_order
    FROM activation
  )
  SELECT
    bucket,
    bucket_order,
    COUNT(*)::bigint AS user_count
  FROM bucketed
  GROUP BY bucket, bucket_order
  ORDER BY bucket_order;
$$;

REVOKE EXECUTE ON FUNCTION admin_time_to_first_sync() FROM anon, authenticated;
;
