
-- =============================================================
-- SECURITY HARDENING MIGRATION
-- Addresses: excessive grants, unsafe functions, storage gaps
-- =============================================================

-- ---------------------------------------------------------
-- 1. RESTRICT ANON ROLE TO SELECT-ONLY ON ALL TABLES
--    The anon role should never write to any table directly.
--    All writes go through authenticated sessions or the
--    service_role via server-side API routes.
-- ---------------------------------------------------------
REVOKE ALL ON public.users FROM anon;
GRANT SELECT ON public.users TO anon;

REVOKE ALL ON public.daily_usage FROM anon;
GRANT SELECT ON public.daily_usage TO anon;

REVOKE ALL ON public.posts FROM anon;
GRANT SELECT ON public.posts TO anon;

REVOKE ALL ON public.follows FROM anon;
GRANT SELECT ON public.follows TO anon;

REVOKE ALL ON public.comments FROM anon;
GRANT SELECT ON public.comments TO anon;

REVOKE ALL ON public.kudos FROM anon;
GRANT SELECT ON public.kudos TO anon;

REVOKE ALL ON public.notifications FROM anon;
GRANT SELECT ON public.notifications TO anon;

REVOKE ALL ON public.cli_auth_codes FROM anon;
GRANT SELECT ON public.cli_auth_codes TO anon;

REVOKE ALL ON public.countries_to_regions FROM anon;
GRANT SELECT ON public.countries_to_regions TO anon;

-- Leaderboard views: SELECT-only for anon
REVOKE ALL ON public.leaderboard_all_time FROM anon;
GRANT SELECT ON public.leaderboard_all_time TO anon;

REVOKE ALL ON public.leaderboard_monthly FROM anon;
GRANT SELECT ON public.leaderboard_monthly TO anon;

REVOKE ALL ON public.leaderboard_weekly FROM anon;
GRANT SELECT ON public.leaderboard_weekly TO anon;

REVOKE ALL ON public.leaderboard_daily FROM anon;
GRANT SELECT ON public.leaderboard_daily TO anon;

-- ---------------------------------------------------------
-- 2. RESTRICT AUTHENTICATED ROLE TO MINIMUM NEEDED GRANTS
--    Matches the actual RLS policies defined per table.
-- ---------------------------------------------------------
REVOKE ALL ON public.users FROM authenticated;
GRANT SELECT, UPDATE ON public.users TO authenticated;

REVOKE ALL ON public.daily_usage FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON public.daily_usage TO authenticated;

REVOKE ALL ON public.posts FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.posts TO authenticated;

REVOKE ALL ON public.follows FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.follows TO authenticated;

REVOKE ALL ON public.comments FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.comments TO authenticated;

REVOKE ALL ON public.kudos FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.kudos TO authenticated;

REVOKE ALL ON public.notifications FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;

REVOKE ALL ON public.cli_auth_codes FROM authenticated;
GRANT SELECT, UPDATE ON public.cli_auth_codes TO authenticated;

REVOKE ALL ON public.countries_to_regions FROM authenticated;
GRANT SELECT ON public.countries_to_regions TO authenticated;

-- Leaderboard views: SELECT-only for authenticated
REVOKE ALL ON public.leaderboard_all_time FROM authenticated;
GRANT SELECT ON public.leaderboard_all_time TO authenticated;

REVOKE ALL ON public.leaderboard_monthly FROM authenticated;
GRANT SELECT ON public.leaderboard_monthly TO authenticated;

REVOKE ALL ON public.leaderboard_weekly FROM authenticated;
GRANT SELECT ON public.leaderboard_weekly TO authenticated;

REVOKE ALL ON public.leaderboard_daily FROM authenticated;
GRANT SELECT ON public.leaderboard_daily TO authenticated;

-- ---------------------------------------------------------
-- 3. LOCK DOWN SECURITY DEFINER FUNCTIONS
--    These functions run with elevated privileges.
--    Only service_role should be able to invoke them.
-- ---------------------------------------------------------

-- lookup_user_id_by_email: queries auth.users — anon/authenticated must not call this
REVOKE EXECUTE ON FUNCTION public.lookup_user_id_by_email(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.lookup_user_id_by_email(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.lookup_user_id_by_email(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_user_id_by_email(text) TO service_role;

-- handle_new_user: trigger function — only invoked by Supabase auth trigger
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;

-- refresh_leaderboards: admin-only operation
REVOKE EXECUTE ON FUNCTION public.refresh_leaderboards() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.refresh_leaderboards() FROM anon;
REVOKE EXECUTE ON FUNCTION public.refresh_leaderboards() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_leaderboards() TO service_role;

-- ---------------------------------------------------------
-- 4. STORAGE BUCKET HARDENING
--    Add file size limits and MIME type restrictions.
-- ---------------------------------------------------------
UPDATE storage.buckets
SET file_size_limit = 5242880,  -- 5 MB
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
WHERE id = 'avatars';

UPDATE storage.buckets
SET file_size_limit = 10485760,  -- 10 MB
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
WHERE id = 'post-images';

-- ---------------------------------------------------------
-- 5. FIX STORAGE UPLOAD POLICIES — ENFORCE FOLDER OWNERSHIP
--    Without this, any authenticated user can upload to any
--    path in the bucket, potentially overwriting other users'
--    files. Enforce that uploads go to the user's own folder.
-- ---------------------------------------------------------

-- Avatars: enforce user owns the folder
DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
CREATE POLICY "Authenticated users can upload avatars"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (auth.uid())::text = (storage.foldername(name))[1]
  );

-- Post images: enforce user owns the folder
DROP POLICY IF EXISTS "Authenticated users can upload post images" ON storage.objects;
CREATE POLICY "Authenticated users can upload post images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'post-images'
    AND auth.role() = 'authenticated'
    AND (auth.uid())::text = (storage.foldername(name))[1]
  );
;
