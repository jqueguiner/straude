
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Leaderboard materialized views
CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_daily AS
SELECT
  u.id as user_id,
  u.username,
  u.avatar_url,
  u.country,
  u.region,
  SUM(d.cost_usd) as total_cost,
  SUM(d.total_tokens) as total_tokens
FROM users u
JOIN daily_usage d ON d.user_id = u.id
WHERE u.is_public = true
  AND u.username IS NOT NULL
  AND d.date = CURRENT_DATE
GROUP BY u.id, u.username, u.avatar_url, u.country, u.region;

CREATE UNIQUE INDEX IF NOT EXISTS leaderboard_daily_user_id ON leaderboard_daily (user_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_weekly AS
SELECT
  u.id as user_id,
  u.username,
  u.avatar_url,
  u.country,
  u.region,
  SUM(d.cost_usd) as total_cost,
  SUM(d.total_tokens) as total_tokens
FROM users u
JOIN daily_usage d ON d.user_id = u.id
WHERE u.is_public = true
  AND u.username IS NOT NULL
  AND d.date >= date_trunc('week', CURRENT_DATE)
GROUP BY u.id, u.username, u.avatar_url, u.country, u.region;

CREATE UNIQUE INDEX IF NOT EXISTS leaderboard_weekly_user_id ON leaderboard_weekly (user_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_monthly AS
SELECT
  u.id as user_id,
  u.username,
  u.avatar_url,
  u.country,
  u.region,
  SUM(d.cost_usd) as total_cost,
  SUM(d.total_tokens) as total_tokens
FROM users u
JOIN daily_usage d ON d.user_id = u.id
WHERE u.is_public = true
  AND u.username IS NOT NULL
  AND d.date >= date_trunc('month', CURRENT_DATE)
GROUP BY u.id, u.username, u.avatar_url, u.country, u.region;

CREATE UNIQUE INDEX IF NOT EXISTS leaderboard_monthly_user_id ON leaderboard_monthly (user_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_all_time AS
SELECT
  u.id as user_id,
  u.username,
  u.avatar_url,
  u.country,
  u.region,
  SUM(d.cost_usd) as total_cost,
  SUM(d.total_tokens) as total_tokens
FROM users u
JOIN daily_usage d ON d.user_id = u.id
WHERE u.is_public = true
  AND u.username IS NOT NULL
GROUP BY u.id, u.username, u.avatar_url, u.country, u.region;

CREATE UNIQUE INDEX IF NOT EXISTS leaderboard_all_time_user_id ON leaderboard_all_time (user_id);

-- Cron jobs to refresh materialized views every 15 minutes
SELECT cron.schedule('refresh-leaderboard-daily', '*/15 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_daily');
SELECT cron.schedule('refresh-leaderboard-weekly', '*/15 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_weekly');
SELECT cron.schedule('refresh-leaderboard-monthly', '*/15 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_monthly');
SELECT cron.schedule('refresh-leaderboard-all-time', '*/15 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_all_time');

-- Cron job to expire old CLI auth codes (every 5 minutes)
SELECT cron.schedule('expire-cli-auth-codes', '*/5 * * * *', $$
  UPDATE cli_auth_codes SET status = 'expired' WHERE status = 'pending' AND expires_at < NOW()
$$);
;
