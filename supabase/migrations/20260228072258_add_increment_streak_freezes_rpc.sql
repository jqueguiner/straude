CREATE OR REPLACE FUNCTION increment_streak_freezes(p_user_id UUID, p_max INTEGER DEFAULT 7)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET streak_freezes = LEAST(streak_freezes + 1, p_max)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;;
