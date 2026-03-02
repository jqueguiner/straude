
-- Cohort retention: signup week cohorts with weekly retention rates
CREATE OR REPLACE FUNCTION admin_cohort_retention()
RETURNS TABLE (
  cohort_week text,
  cohort_size bigint,
  week_0 numeric,
  week_1 numeric,
  week_2 numeric,
  week_3 numeric,
  week_4 numeric
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
  cohorts AS (
    SELECT
      id AS user_id,
      date_trunc('week', created_at)::date AS cohort_week
    FROM real_users
  ),
  activity AS (
    SELECT DISTINCT
      du.user_id,
      date_trunc('week', du.date::timestamp)::date AS active_week
    FROM daily_usage du
    JOIN real_users ru ON du.user_id = ru.id
  ),
  retention AS (
    SELECT
      c.cohort_week,
      c.user_id,
      a.active_week,
      EXTRACT(days FROM a.active_week::timestamp - c.cohort_week::timestamp)::int / 7 AS week_number
    FROM cohorts c
    LEFT JOIN activity a ON c.user_id = a.user_id
  )
  SELECT
    to_char(r.cohort_week, 'Mon DD') AS cohort_week,
    COUNT(DISTINCT r.user_id) AS cohort_size,
    ROUND(COUNT(DISTINCT CASE WHEN week_number = 0 THEN r.user_id END) * 100.0 / NULLIF(COUNT(DISTINCT r.user_id), 0), 1) AS week_0,
    ROUND(COUNT(DISTINCT CASE WHEN week_number = 1 THEN r.user_id END) * 100.0 / NULLIF(COUNT(DISTINCT r.user_id), 0), 1) AS week_1,
    ROUND(COUNT(DISTINCT CASE WHEN week_number = 2 THEN r.user_id END) * 100.0 / NULLIF(COUNT(DISTINCT r.user_id), 0), 1) AS week_2,
    ROUND(COUNT(DISTINCT CASE WHEN week_number = 3 THEN r.user_id END) * 100.0 / NULLIF(COUNT(DISTINCT r.user_id), 0), 1) AS week_3,
    ROUND(COUNT(DISTINCT CASE WHEN week_number = 4 THEN r.user_id END) * 100.0 / NULLIF(COUNT(DISTINCT r.user_id), 0), 1) AS week_4
  FROM retention r
  GROUP BY r.cohort_week
  ORDER BY r.cohort_week DESC
  LIMIT 12;
$$;

REVOKE EXECUTE ON FUNCTION admin_cohort_retention() FROM anon, authenticated;
;
