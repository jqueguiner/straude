
-- Fix RLS performance: wrap auth.uid() in (select ...) to prevent per-row re-evaluation
-- See: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
CREATE POLICY "Users can read own notifications"
  ON notifications FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING ((select auth.uid()) = user_id);
;
