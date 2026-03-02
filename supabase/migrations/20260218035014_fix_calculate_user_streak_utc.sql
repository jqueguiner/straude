CREATE OR REPLACE FUNCTION public.calculate_user_streak(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $$
DECLARE
  streak_count INTEGER := 0;
  current_date_check DATE;
  has_usage BOOLEAN;
BEGIN
  -- Start from today; if no usage today, try yesterday
  SELECT EXISTS(
    SELECT 1 FROM public.daily_usage
    WHERE user_id = p_user_id AND date = CURRENT_DATE
  ) INTO has_usage;

  IF has_usage THEN
    current_date_check := CURRENT_DATE;
  ELSE
    SELECT EXISTS(
      SELECT 1 FROM public.daily_usage
      WHERE user_id = p_user_id AND date = CURRENT_DATE - 1
    ) INTO has_usage;
    IF has_usage THEN
      current_date_check := CURRENT_DATE - 1;
    ELSE
      RETURN 0;
    END IF;
  END IF;

  -- Count consecutive days backward
  LOOP
    SELECT EXISTS(
      SELECT 1 FROM public.daily_usage
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
$$;;
