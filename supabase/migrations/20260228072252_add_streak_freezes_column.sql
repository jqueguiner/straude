ALTER TABLE public.users ADD COLUMN IF NOT EXISTS streak_freezes integer NOT NULL DEFAULT 0;;
