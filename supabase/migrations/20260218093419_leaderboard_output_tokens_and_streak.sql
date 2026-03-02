
-- 1. Recreate all leaderboard views to show output_tokens instead of total_tokens

DROP MATERIALIZED VIEW IF EXISTS leaderboard_daily;
CREATE MATERIALIZED VIEW leaderboard_daily AS
SELECT
  u.id AS user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(sum(d.cost_usd), 0) AS total_cost,
  COALESCE(sum(d.output_tokens), 0) AS total_output_tokens,
  count(d.id) AS session_count
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date = CURRENT_DATE
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(sum(d.cost_usd), 0) > 0
ORDER BY COALESCE(sum(d.cost_usd), 0) DESC;

DROP MATERIALIZED VIEW IF EXISTS leaderboard_weekly;
CREATE MATERIALIZED VIEW leaderboard_weekly AS
SELECT
  u.id AS user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(sum(d.cost_usd), 0) AS total_cost,
  COALESCE(sum(d.output_tokens), 0) AS total_output_tokens,
  count(DISTINCT d.date) AS active_days
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date >= (CURRENT_DATE - '6 days'::interval)
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(sum(d.cost_usd), 0) > 0
ORDER BY COALESCE(sum(d.cost_usd), 0) DESC;

DROP MATERIALIZED VIEW IF EXISTS leaderboard_monthly;
CREATE MATERIALIZED VIEW leaderboard_monthly AS
SELECT
  u.id AS user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(sum(d.cost_usd), 0) AS total_cost,
  COALESCE(sum(d.output_tokens), 0) AS total_output_tokens,
  count(DISTINCT d.date) AS active_days
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date >= (CURRENT_DATE - '29 days'::interval)
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(sum(d.cost_usd), 0) > 0
ORDER BY COALESCE(sum(d.cost_usd), 0) DESC;

DROP MATERIALIZED VIEW IF EXISTS leaderboard_all_time;
CREATE MATERIALIZED VIEW leaderboard_all_time AS
SELECT
  u.id AS user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(sum(d.cost_usd), 0) AS total_cost,
  COALESCE(sum(d.output_tokens), 0) AS total_output_tokens,
  count(DISTINCT d.date) AS active_days
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(sum(d.cost_usd), 0) > 0
ORDER BY COALESCE(sum(d.cost_usd), 0) DESC;

-- 2. Create batch streak function (single RPC call for all leaderboard users)
CREATE OR REPLACE FUNCTION calculate_streaks_batch(p_user_ids UUID[])
RETURNS TABLE(user_id UUID, streak INTEGER) AS $$
BEGIN
  RETURN QUERY
  SELECT uid, public.calculate_user_streak(uid)
  FROM unnest(p_user_ids) AS uid;
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. Refresh all views with the new column
REFRESH MATERIALIZED VIEW leaderboard_daily;
REFRESH MATERIALIZED VIEW leaderboard_weekly;
REFRESH MATERIALIZED VIEW leaderboard_monthly;
REFRESH MATERIALIZED VIEW leaderboard_all_time;
;
