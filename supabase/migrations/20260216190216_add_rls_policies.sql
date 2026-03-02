
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE kudos ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE cli_auth_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE countries_to_regions ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON users FOR SELECT
  USING (is_public = true OR id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (id = auth.uid());

-- Daily usage policies
CREATE POLICY "Users can view own usage"
  ON daily_usage FOR SELECT
  USING (user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM users WHERE users.id = daily_usage.user_id AND users.is_public = true
  ));

CREATE POLICY "Users can insert own usage"
  ON daily_usage FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own usage"
  ON daily_usage FOR UPDATE
  USING (user_id = auth.uid());

-- Posts policies
CREATE POLICY "Public posts viewable by everyone"
  ON posts FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = posts.user_id AND users.is_public = true)
    OR posts.user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM follows WHERE follows.follower_id = auth.uid() AND follows.following_id = posts.user_id)
  );

CREATE POLICY "Users can insert own posts"
  ON posts FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own posts"
  ON posts FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own posts"
  ON posts FOR DELETE
  USING (user_id = auth.uid());

-- Follows policies
CREATE POLICY "Anyone can view follows"
  ON follows FOR SELECT
  USING (true);

CREATE POLICY "Users can follow"
  ON follows FOR INSERT
  WITH CHECK (follower_id = auth.uid());

CREATE POLICY "Users can unfollow"
  ON follows FOR DELETE
  USING (follower_id = auth.uid());

-- Kudos policies
CREATE POLICY "Anyone can view kudos"
  ON kudos FOR SELECT
  USING (true);

CREATE POLICY "Users can give kudos"
  ON kudos FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can remove kudos"
  ON kudos FOR DELETE
  USING (user_id = auth.uid());

-- Comments policies
CREATE POLICY "Anyone can view comments on visible posts"
  ON comments FOR SELECT
  USING (true);

CREATE POLICY "Users can comment"
  ON comments FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can edit own comments"
  ON comments FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own comments"
  ON comments FOR DELETE
  USING (user_id = auth.uid());

-- CLI auth codes: service role only (no RLS needed for users)
CREATE POLICY "Service role manages cli auth codes"
  ON cli_auth_codes FOR ALL
  USING (true);

-- Countries lookup is public
CREATE POLICY "Countries lookup is public"
  ON countries_to_regions FOR SELECT
  USING (true);
;
