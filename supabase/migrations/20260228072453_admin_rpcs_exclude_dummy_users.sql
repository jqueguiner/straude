
-- Dummy/seed users share this UUID prefix
-- a0000000-0000-4000-8000-00000000000*

CREATE OR REPLACE FUNCTION admin_cumulative_spend()
RETURNS TABLE(date date, daily_total numeric, cumulative_total numeric)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    d.date,
    SUM(d.cost_usd) AS daily_total,
    SUM(SUM(d.cost_usd)) OVER (ORDER BY d.date) AS cumulative_total
  FROM daily_usage d
  WHERE d.user_id NOT IN (SELECT id FROM users WHERE id::text LIKE 'a0000000-0000-4000-8000-%')
  GROUP BY d.date
  ORDER BY d.date;
$$;

CREATE OR REPLACE FUNCTION admin_top_users(p_limit int DEFAULT 20)
RETURNS TABLE(
  user_id uuid,
  username text,
  avatar_url text,
  total_spend numeric,
  total_tokens bigint,
  usage_days bigint,
  last_active date,
  signed_up timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    u.id AS user_id,
    u.username,
    u.avatar_url,
    SUM(d.cost_usd) AS total_spend,
    SUM(d.total_tokens) AS total_tokens,
    COUNT(DISTINCT d.date) AS usage_days,
    MAX(d.date) AS last_active,
    u.created_at AS signed_up
  FROM users u
  JOIN daily_usage d ON d.user_id = u.id
  WHERE u.id::text NOT LIKE 'a0000000-0000-4000-8000-%'
  GROUP BY u.id, u.username, u.avatar_url, u.created_at
  ORDER BY total_spend DESC
  LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION admin_activation_funnel()
RETURNS TABLE(stage text, count bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT 'signed_up' AS stage, COUNT(*) FROM users WHERE id::text NOT LIKE 'a0000000-0000-4000-8000-%'
  UNION ALL
  SELECT 'onboarded', COUNT(*) FROM users WHERE onboarding_completed = true AND id::text NOT LIKE 'a0000000-0000-4000-8000-%'
  UNION ALL
  SELECT 'first_usage', COUNT(DISTINCT user_id) FROM daily_usage WHERE user_id NOT IN (SELECT id FROM users WHERE id::text LIKE 'a0000000-0000-4000-8000-%')
  UNION ALL
  SELECT 'first_post', COUNT(DISTINCT user_id) FROM posts WHERE user_id NOT IN (SELECT id FROM users WHERE id::text LIKE 'a0000000-0000-4000-8000-%')
  UNION ALL
  SELECT 'retained_3d', COUNT(DISTINCT user_id) FROM (
    SELECT user_id FROM daily_usage
    WHERE user_id NOT IN (SELECT id FROM users WHERE id::text LIKE 'a0000000-0000-4000-8000-%')
    GROUP BY user_id HAVING COUNT(DISTINCT date) >= 3
  ) sub;
$$;

CREATE OR REPLACE FUNCTION admin_growth_metrics()
RETURNS TABLE(date date, signups bigint, cumulative_users bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    d.date,
    d.signups,
    SUM(d.signups) OVER (ORDER BY d.date) AS cumulative_users
  FROM (
    SELECT
      created_at::date AS date,
      COUNT(*) AS signups
    FROM users
    WHERE id::text NOT LIKE 'a0000000-0000-4000-8000-%'
    GROUP BY created_at::date
  ) d
  ORDER BY d.date;
$$;
;
