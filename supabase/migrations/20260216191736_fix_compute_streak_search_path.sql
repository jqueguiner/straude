
-- Fix compute_streak function search_path
CREATE OR REPLACE FUNCTION public.compute_streak(target_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  streak_count INTEGER := 0;
  check_date DATE := CURRENT_DATE;
  has_usage BOOLEAN;
BEGIN
  -- First check if there's usage today or yesterday (allow 1 day grace)
  SELECT EXISTS(
    SELECT 1 FROM public.daily_usage
    WHERE user_id = target_user_id AND date IN (CURRENT_DATE, CURRENT_DATE - 1)
  ) INTO has_usage;

  IF NOT has_usage THEN
    RETURN 0;
  END IF;

  -- If no usage today, start counting from yesterday
  IF NOT EXISTS(SELECT 1 FROM public.daily_usage WHERE user_id = target_user_id AND date = CURRENT_DATE) THEN
    check_date := CURRENT_DATE - 1;
  END IF;

  -- Count consecutive days backwards
  LOOP
    SELECT EXISTS(
      SELECT 1 FROM public.daily_usage
      WHERE user_id = target_user_id AND date = check_date
    ) INTO has_usage;

    EXIT WHEN NOT has_usage;

    streak_count := streak_count + 1;
    check_date := check_date - 1;
  END LOOP;

  RETURN streak_count;
END;
$$;
;
