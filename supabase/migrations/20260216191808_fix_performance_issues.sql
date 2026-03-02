
-- =============================================
-- Migration: fix_performance_issues
-- Fixes RLS initplan, duplicate indexes, missing FK indexes
-- =============================================

-- ==========================================
-- Step 1: Fix RLS policies to use (select auth.uid())
-- This prevents per-row re-evaluation
-- ==========================================

-- users
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
CREATE POLICY "Public profiles are viewable by everyone"
  ON users FOR SELECT
  USING (is_public = true OR id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (id = (select auth.uid()));

-- daily_usage
DROP POLICY IF EXISTS "Users can view own usage" ON daily_usage;
CREATE POLICY "Users can view own usage"
  ON daily_usage FOR SELECT
  USING (
    user_id = (select auth.uid())
    OR EXISTS (SELECT 1 FROM users WHERE users.id = daily_usage.user_id AND users.is_public = true)
  );

DROP POLICY IF EXISTS "Users can insert own usage" ON daily_usage;
CREATE POLICY "Users can insert own usage"
  ON daily_usage FOR INSERT
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own usage" ON daily_usage;
CREATE POLICY "Users can update own usage"
  ON daily_usage FOR UPDATE
  USING (user_id = (select auth.uid()));

-- posts
DROP POLICY IF EXISTS "Public posts viewable by everyone" ON posts;
CREATE POLICY "Public posts viewable by everyone"
  ON posts FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = posts.user_id AND users.is_public = true)
    OR user_id = (select auth.uid())
    OR EXISTS (SELECT 1 FROM follows WHERE follows.follower_id = (select auth.uid()) AND follows.following_id = posts.user_id)
  );

DROP POLICY IF EXISTS "Users can insert own posts" ON posts;
CREATE POLICY "Users can insert own posts"
  ON posts FOR INSERT
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own posts" ON posts;
CREATE POLICY "Users can update own posts"
  ON posts FOR UPDATE
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own posts" ON posts;
CREATE POLICY "Users can delete own posts"
  ON posts FOR DELETE
  USING (user_id = (select auth.uid()));

-- follows
DROP POLICY IF EXISTS "Users can follow" ON follows;
CREATE POLICY "Users can follow"
  ON follows FOR INSERT
  WITH CHECK (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can unfollow" ON follows;
CREATE POLICY "Users can unfollow"
  ON follows FOR DELETE
  USING (follower_id = (select auth.uid()));

-- kudos
DROP POLICY IF EXISTS "Users can give kudos" ON kudos;
CREATE POLICY "Users can give kudos"
  ON kudos FOR INSERT
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can remove kudos" ON kudos;
CREATE POLICY "Users can remove kudos"
  ON kudos FOR DELETE
  USING (user_id = (select auth.uid()));

-- comments
DROP POLICY IF EXISTS "Users can comment" ON comments;
CREATE POLICY "Users can comment"
  ON comments FOR INSERT
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can edit own comments" ON comments;
CREATE POLICY "Users can edit own comments"
  ON comments FOR UPDATE
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own comments" ON comments;
CREATE POLICY "Users can delete own comments"
  ON comments FOR DELETE
  USING (user_id = (select auth.uid()));

-- cli_auth_codes
DROP POLICY IF EXISTS "Users can view own cli auth codes" ON cli_auth_codes;
CREATE POLICY "Users can view own cli auth codes"
  ON cli_auth_codes FOR SELECT
  USING (user_id = (select auth.uid()) OR status = 'pending');

DROP POLICY IF EXISTS "Authenticated users can verify pending codes" ON cli_auth_codes;
CREATE POLICY "Authenticated users can verify pending codes"
  ON cli_auth_codes FOR UPDATE
  USING (status = 'pending')
  WITH CHECK (user_id = (select auth.uid()) AND status IN ('pending', 'completed'));

-- ==========================================
-- Step 2: Drop duplicate indexes on materialized views
-- ==========================================
DROP INDEX IF EXISTS leaderboard_daily_user_id;
DROP INDEX IF EXISTS leaderboard_weekly_user_id;
DROP INDEX IF EXISTS leaderboard_monthly_user_id;
DROP INDEX IF EXISTS leaderboard_all_time_user_id;

-- ==========================================
-- Step 3: Add missing FK indexes
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_cli_auth_codes_user_id ON cli_auth_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
;
