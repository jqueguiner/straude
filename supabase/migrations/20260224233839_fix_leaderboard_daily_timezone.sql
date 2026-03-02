CREATE OR REPLACE VIEW public.leaderboard_daily AS
WITH latest_usage AS (
  SELECT user_id, MAX(date) AS max_date
  FROM daily_usage
  WHERE date >= CURRENT_DATE - INTERVAL '1 day'
  GROUP BY user_id
),
daily_agg AS (
  SELECT
    d.user_id,
    COALESCE(SUM(d.cost_usd), 0)         AS total_cost,
    COALESCE(SUM(d.output_tokens), 0)    AS total_output_tokens,
    COUNT(d.id)                           AS session_count
  FROM daily_usage d
  JOIN latest_usage lu ON d.user_id = lu.user_id AND d.date = lu.max_date
  GROUP BY d.user_id
)
SELECT
  u.id            AS user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  da.total_cost,
  da.total_output_tokens,
  da.session_count
FROM users u
JOIN daily_agg da ON da.user_id = u.id
WHERE u.is_public = true
  AND u.onboarding_completed = true
ORDER BY da.total_cost DESC;;
