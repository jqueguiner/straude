
-- Create the function with the name the code expects
CREATE OR REPLACE FUNCTION calculate_user_streak(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  streak_count INTEGER := 0;
  check_date DATE := CURRENT_DATE;
  has_usage BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM daily_usage
    WHERE user_id = p_user_id AND date IN (CURRENT_DATE, CURRENT_DATE - 1)
  ) INTO has_usage;

  IF NOT has_usage THEN
    RETURN 0;
  END IF;

  IF NOT EXISTS(SELECT 1 FROM daily_usage WHERE user_id = p_user_id AND date = CURRENT_DATE) THEN
    check_date := CURRENT_DATE - 1;
  END IF;

  LOOP
    SELECT EXISTS(
      SELECT 1 FROM daily_usage
      WHERE user_id = p_user_id AND date = check_date
    ) INTO has_usage;

    EXIT WHEN NOT has_usage;
    streak_count := streak_count + 1;
    check_date := check_date - 1;
  END LOOP;

  RETURN streak_count;
END;
$$ LANGUAGE plpgsql STABLE;
;
