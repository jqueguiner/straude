
-- Drop materialized views
DROP MATERIALIZED VIEW IF EXISTS leaderboard_daily;
DROP MATERIALIZED VIEW IF EXISTS leaderboard_weekly;
DROP MATERIALIZED VIEW IF EXISTS leaderboard_monthly;
DROP MATERIALIZED VIEW IF EXISTS leaderboard_all_time;

-- Recreate as regular views (real-time)
CREATE VIEW leaderboard_daily AS
  SELECT u.id AS user_id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.country,
    u.region,
    COALESCE(sum(d.cost_usd), 0::numeric) AS total_cost,
    COALESCE(sum(d.output_tokens), 0::numeric) AS total_output_tokens,
    count(d.id) AS session_count
  FROM users u
    LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date = CURRENT_DATE
  WHERE u.is_public = true AND u.onboarding_completed = true
  GROUP BY u.id
  HAVING COALESCE(sum(d.cost_usd), 0::numeric) > 0::numeric
  ORDER BY COALESCE(sum(d.cost_usd), 0::numeric) DESC;

CREATE VIEW leaderboard_weekly AS
  SELECT u.id AS user_id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.country,
    u.region,
    COALESCE(sum(d.cost_usd), 0::numeric) AS total_cost,
    COALESCE(sum(d.output_tokens), 0::numeric) AS total_output_tokens,
    count(DISTINCT d.date) AS active_days
  FROM users u
    LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date >= (CURRENT_DATE - '6 days'::interval)
  WHERE u.is_public = true AND u.onboarding_completed = true
  GROUP BY u.id
  HAVING COALESCE(sum(d.cost_usd), 0::numeric) > 0::numeric
  ORDER BY COALESCE(sum(d.cost_usd), 0::numeric) DESC;

CREATE VIEW leaderboard_monthly AS
  SELECT u.id AS user_id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.country,
    u.region,
    COALESCE(sum(d.cost_usd), 0::numeric) AS total_cost,
    COALESCE(sum(d.output_tokens), 0::numeric) AS total_output_tokens,
    count(DISTINCT d.date) AS active_days
  FROM users u
    LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date >= (CURRENT_DATE - '29 days'::interval)
  WHERE u.is_public = true AND u.onboarding_completed = true
  GROUP BY u.id
  HAVING COALESCE(sum(d.cost_usd), 0::numeric) > 0::numeric
  ORDER BY COALESCE(sum(d.cost_usd), 0::numeric) DESC;

CREATE VIEW leaderboard_all_time AS
  SELECT u.id AS user_id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.country,
    u.region,
    COALESCE(sum(d.cost_usd), 0::numeric) AS total_cost,
    COALESCE(sum(d.output_tokens), 0::numeric) AS total_output_tokens,
    count(DISTINCT d.date) AS active_days
  FROM users u
    LEFT JOIN daily_usage d ON d.user_id = u.id
  WHERE u.is_public = true AND u.onboarding_completed = true
  GROUP BY u.id
  HAVING COALESCE(sum(d.cost_usd), 0::numeric) > 0::numeric
  ORDER BY COALESCE(sum(d.cost_usd), 0::numeric) DESC;

-- Remove the cron jobs (no longer needed)
SELECT cron.unschedule('refresh-leaderboard-daily');
SELECT cron.unschedule('refresh-leaderboard-weekly');
SELECT cron.unschedule('refresh-leaderboard-monthly');
SELECT cron.unschedule('refresh-leaderboard-all-time');
;
