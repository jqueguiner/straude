-- Straude v1 Database Schema
-- Materialized views for leaderboard

-- Daily leaderboard
CREATE MATERIALIZED VIEW leaderboard_daily AS
SELECT
  u.id as user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(SUM(d.cost_usd), 0) as total_cost,
  COALESCE(SUM(d.total_tokens), 0) as total_tokens,
  COUNT(d.id) as session_count
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date = CURRENT_DATE
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(SUM(d.cost_usd), 0) > 0
ORDER BY total_cost DESC;
CREATE UNIQUE INDEX idx_leaderboard_daily_user ON leaderboard_daily(user_id);
CREATE INDEX idx_leaderboard_daily_cost ON leaderboard_daily(total_cost DESC);
CREATE INDEX idx_leaderboard_daily_region ON leaderboard_daily(region, total_cost DESC);
-- Weekly leaderboard (last 7 days)
CREATE MATERIALIZED VIEW leaderboard_weekly AS
SELECT
  u.id as user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(SUM(d.cost_usd), 0) as total_cost,
  COALESCE(SUM(d.total_tokens), 0) as total_tokens,
  COUNT(DISTINCT d.date) as active_days
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date >= CURRENT_DATE - INTERVAL '6 days'
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(SUM(d.cost_usd), 0) > 0
ORDER BY total_cost DESC;
CREATE UNIQUE INDEX idx_leaderboard_weekly_user ON leaderboard_weekly(user_id);
CREATE INDEX idx_leaderboard_weekly_cost ON leaderboard_weekly(total_cost DESC);
CREATE INDEX idx_leaderboard_weekly_region ON leaderboard_weekly(region, total_cost DESC);
-- Monthly leaderboard (last 30 days)
CREATE MATERIALIZED VIEW leaderboard_monthly AS
SELECT
  u.id as user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(SUM(d.cost_usd), 0) as total_cost,
  COALESCE(SUM(d.total_tokens), 0) as total_tokens,
  COUNT(DISTINCT d.date) as active_days
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id AND d.date >= CURRENT_DATE - INTERVAL '29 days'
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(SUM(d.cost_usd), 0) > 0
ORDER BY total_cost DESC;
CREATE UNIQUE INDEX idx_leaderboard_monthly_user ON leaderboard_monthly(user_id);
CREATE INDEX idx_leaderboard_monthly_cost ON leaderboard_monthly(total_cost DESC);
CREATE INDEX idx_leaderboard_monthly_region ON leaderboard_monthly(region, total_cost DESC);
-- All-time leaderboard
CREATE MATERIALIZED VIEW leaderboard_all_time AS
SELECT
  u.id as user_id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.country,
  u.region,
  COALESCE(SUM(d.cost_usd), 0) as total_cost,
  COALESCE(SUM(d.total_tokens), 0) as total_tokens,
  COUNT(DISTINCT d.date) as active_days
FROM users u
LEFT JOIN daily_usage d ON d.user_id = u.id
WHERE u.is_public = true AND u.onboarding_completed = true
GROUP BY u.id
HAVING COALESCE(SUM(d.cost_usd), 0) > 0
ORDER BY total_cost DESC;
CREATE UNIQUE INDEX idx_leaderboard_all_time_user ON leaderboard_all_time(user_id);
CREATE INDEX idx_leaderboard_all_time_cost ON leaderboard_all_time(total_cost DESC);
CREATE INDEX idx_leaderboard_all_time_region ON leaderboard_all_time(region, total_cost DESC);
-- Function to refresh all leaderboard views
CREATE OR REPLACE FUNCTION refresh_leaderboards()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_daily;
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_weekly;
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_monthly;
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_all_time;
END;
$$ LANGUAGE plpgsql;
-- User streak calculation function
CREATE OR REPLACE FUNCTION calculate_user_streak(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  streak_count INTEGER := 0;
  current_date_check DATE := CURRENT_DATE;
  has_usage BOOLEAN;
BEGIN
  -- Check consecutive days starting from today
  LOOP
    SELECT EXISTS(
      SELECT 1 FROM daily_usage
      WHERE user_id = p_user_id AND date = current_date_check
    ) INTO has_usage;

    IF has_usage THEN
      streak_count := streak_count + 1;
      current_date_check := current_date_check - 1;
    ELSE
      EXIT;
    END IF;
  END LOOP;

  RETURN streak_count;
END;
$$ LANGUAGE plpgsql;
