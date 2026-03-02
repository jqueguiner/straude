
-- Fix mutable search_path on calculate_streaks_batch (flagged by Supabase security advisor)
ALTER FUNCTION public.calculate_streaks_batch(UUID[])
SET search_path = public;
;
