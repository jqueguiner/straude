
-- Fix SECURITY DEFINER views to use SECURITY INVOKER instead.
-- This ensures RLS policies of the querying user are enforced,
-- not those of the view creator.

ALTER VIEW public.leaderboard_all_time SET (security_invoker = on);
ALTER VIEW public.leaderboard_monthly SET (security_invoker = on);
ALTER VIEW public.leaderboard_weekly SET (security_invoker = on);
ALTER VIEW public.leaderboard_daily SET (security_invoker = on);
;
