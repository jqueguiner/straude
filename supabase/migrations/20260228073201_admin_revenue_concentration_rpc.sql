
-- Revenue concentration: how much spend is concentrated among top users
CREATE OR REPLACE FUNCTION admin_revenue_concentration()
RETURNS TABLE (
  segment text,
  user_count bigint,
  total_spend numeric,
  pct_of_total numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH real_spend AS (
    SELECT
      du.user_id,
      SUM(du.cost_usd) AS total_spend
    FROM daily_usage du
    WHERE du.user_id::text NOT LIKE 'a0000000-0000-4000-8000-%'
    GROUP BY du.user_id
    ORDER BY total_spend DESC
  ),
  ranked AS (
    SELECT
      user_id,
      total_spend,
      ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS rank,
      COUNT(*) OVER () AS total_users,
      SUM(total_spend) OVER () AS grand_total
    FROM real_spend
  ),
  segments AS (
    SELECT
      CASE
        WHEN rank <= 1 THEN 'top_1'
        WHEN rank <= 5 THEN 'top_5'
        WHEN rank <= 10 THEN 'top_10'
        ELSE 'rest'
      END AS segment,
      user_id,
      total_spend,
      grand_total
    FROM ranked
  )
  SELECT
    s.segment,
    COUNT(*)::bigint AS user_count,
    ROUND(SUM(s.total_spend)::numeric, 2) AS total_spend,
    ROUND(SUM(s.total_spend) * 100.0 / NULLIF(MAX(s.grand_total), 0), 1) AS pct_of_total
  FROM segments s
  GROUP BY s.segment
  ORDER BY
    CASE s.segment
      WHEN 'top_1' THEN 1
      WHEN 'top_5' THEN 2
      WHEN 'top_10' THEN 3
      ELSE 4
    END;
$$;

REVOKE EXECUTE ON FUNCTION admin_revenue_concentration() FROM anon, authenticated;
;
