-- User-submitted prompts for product requests and bug fixes.
CREATE TABLE IF NOT EXISTS public.prompt_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  prompt text NOT NULL,
  is_anonymous boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'new' CHECK (
    status IN ('new', 'accepted', 'in_progress', 'rejected', 'shipped')
  ),
  is_public boolean NOT NULL DEFAULT true,
  is_hidden boolean NOT NULL DEFAULT false,
  admin_notes text,
  pr_url text,
  shipped_at timestamptz,
  reviewed_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prompt_submissions_status_created_idx
  ON public.prompt_submissions (status, created_at DESC);
CREATE INDEX IF NOT EXISTS prompt_submissions_user_created_idx
  ON public.prompt_submissions (user_id, created_at DESC);
ALTER TABLE public.prompt_submissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can create their own prompt submissions" ON public.prompt_submissions;
CREATE POLICY "Users can create their own prompt submissions"
  ON public.prompt_submissions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Authenticated users can view visible prompt submissions" ON public.prompt_submissions;
CREATE POLICY "Authenticated users can view visible prompt submissions"
  ON public.prompt_submissions
  FOR SELECT
  TO authenticated
  USING (is_public = true AND is_hidden = false);
