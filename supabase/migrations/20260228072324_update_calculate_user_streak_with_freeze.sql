-- Replace the existing function to add p_freeze_days parameter with default 0
CREATE OR REPLACE FUNCTION public.calculate_user_streak(p_user_id uuid, p_freeze_days integer DEFAULT 0)
RETURNS integer
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $function$
DECLARE
  streak_count INTEGER := 0;
  current_date_check DATE;
  has_usage BOOLEAN;
  latest_date DATE;
  grace INTEGER := 2 + p_freeze_days;
BEGIN
  SELECT MAX(date) INTO latest_date
  FROM public.daily_usage
  WHERE user_id = p_user_id;

  IF latest_date IS NULL THEN
    RETURN 0;
  END IF;

  -- Grace period: 2 days (timezone buffer) + freeze days
  IF latest_date < CURRENT_DATE - grace THEN
    RETURN 0;
  END IF;

  current_date_check := latest_date;
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
$function$;;
