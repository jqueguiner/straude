-- Straude v1 Database Schema
-- Initial migration: Core tables

-- Country to region mapping
CREATE TABLE countries_to_regions (
  country_code TEXT PRIMARY KEY,
  region TEXT NOT NULL CHECK (region IN ('north_america', 'south_america', 'europe', 'asia', 'africa', 'oceania'))
);
-- Users (synced from Clerk via webhook)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clerk_id TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL CHECK (username ~ '^[a-zA-Z0-9_]{3,20}$'),
  display_name TEXT,
  bio TEXT CHECK (char_length(bio) <= 160),
  avatar_url TEXT,
  country TEXT NOT NULL,
  region TEXT NOT NULL CHECK (region IN ('north_america', 'south_america', 'europe', 'asia', 'africa', 'oceania')),
  link TEXT CHECK (char_length(link) <= 200),
  github_username TEXT,
  is_public BOOLEAN DEFAULT true NOT NULL,
  timezone TEXT NOT NULL,
  onboarding_completed BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- Usage data (daily aggregates)
CREATE TABLE daily_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  cost_usd DECIMAL(10, 4) NOT NULL CHECK (cost_usd >= 0),
  input_tokens BIGINT NOT NULL CHECK (input_tokens >= 0),
  output_tokens BIGINT NOT NULL CHECK (output_tokens >= 0),
  cache_creation_tokens BIGINT DEFAULT 0 CHECK (cache_creation_tokens >= 0),
  cache_read_tokens BIGINT DEFAULT 0 CHECK (cache_read_tokens >= 0),
  total_tokens BIGINT NOT NULL CHECK (total_tokens >= 0),
  models JSONB DEFAULT '[]'::jsonb NOT NULL,
  session_count INTEGER DEFAULT 1 CHECK (session_count >= 1),
  is_verified BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, date)
);
-- Posts (user-facing content layer on top of daily_usage)
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  daily_usage_id UUID REFERENCES daily_usage(id) ON DELETE CASCADE NOT NULL UNIQUE,
  description TEXT CHECK (char_length(description) <= 500),
  images JSONB DEFAULT '[]'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- Follows
CREATE TABLE follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);
-- Likes
CREATE TABLE likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, post_id)
);
-- Comments
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL CHECK (char_length(content) <= 500 AND char_length(content) >= 1),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- CLI auth codes (for device flow)
CREATE TABLE cli_auth_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- Indexes for performance
CREATE INDEX idx_users_clerk_id ON users(clerk_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_daily_usage_user_date ON daily_usage(user_id, date DESC);
CREATE INDEX idx_daily_usage_date ON daily_usage(date DESC);
CREATE INDEX idx_posts_user ON posts(user_id, created_at DESC);
CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);
CREATE INDEX idx_likes_post ON likes(post_id);
CREATE INDEX idx_likes_user ON likes(user_id);
CREATE INDEX idx_comments_post ON comments(post_id, created_at ASC);
CREATE INDEX idx_cli_auth_codes_code ON cli_auth_codes(code);
-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';
-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Seed countries_to_regions
INSERT INTO countries_to_regions (country_code, region) VALUES
  -- North America
  ('US', 'north_america'), ('CA', 'north_america'), ('MX', 'north_america'),
  ('GT', 'north_america'), ('BZ', 'north_america'), ('HN', 'north_america'),
  ('SV', 'north_america'), ('NI', 'north_america'), ('CR', 'north_america'),
  ('PA', 'north_america'), ('CU', 'north_america'), ('JM', 'north_america'),
  ('HT', 'north_america'), ('DO', 'north_america'), ('PR', 'north_america'),
  ('TT', 'north_america'), ('BB', 'north_america'), ('BS', 'north_america'),
  -- South America
  ('BR', 'south_america'), ('AR', 'south_america'), ('CL', 'south_america'),
  ('CO', 'south_america'), ('PE', 'south_america'), ('VE', 'south_america'),
  ('EC', 'south_america'), ('BO', 'south_america'), ('PY', 'south_america'),
  ('UY', 'south_america'), ('GY', 'south_america'), ('SR', 'south_america'),
  -- Europe
  ('GB', 'europe'), ('DE', 'europe'), ('FR', 'europe'), ('ES', 'europe'),
  ('IT', 'europe'), ('NL', 'europe'), ('BE', 'europe'), ('PT', 'europe'),
  ('PL', 'europe'), ('SE', 'europe'), ('NO', 'europe'), ('DK', 'europe'),
  ('FI', 'europe'), ('CH', 'europe'), ('AT', 'europe'), ('IE', 'europe'),
  ('CZ', 'europe'), ('RO', 'europe'), ('HU', 'europe'), ('GR', 'europe'),
  ('UA', 'europe'), ('SK', 'europe'), ('BG', 'europe'), ('HR', 'europe'),
  ('RS', 'europe'), ('SI', 'europe'), ('LT', 'europe'), ('LV', 'europe'),
  ('EE', 'europe'), ('LU', 'europe'), ('MT', 'europe'), ('CY', 'europe'),
  ('IS', 'europe'), ('AL', 'europe'), ('MK', 'europe'), ('ME', 'europe'),
  ('BA', 'europe'), ('MD', 'europe'), ('BY', 'europe'), ('RU', 'europe'),
  -- Asia
  ('CN', 'asia'), ('JP', 'asia'), ('KR', 'asia'), ('IN', 'asia'),
  ('ID', 'asia'), ('TH', 'asia'), ('VN', 'asia'), ('PH', 'asia'),
  ('MY', 'asia'), ('SG', 'asia'), ('TW', 'asia'), ('HK', 'asia'),
  ('PK', 'asia'), ('BD', 'asia'), ('LK', 'asia'), ('NP', 'asia'),
  ('MM', 'asia'), ('KH', 'asia'), ('LA', 'asia'), ('MN', 'asia'),
  ('KZ', 'asia'), ('UZ', 'asia'), ('AZ', 'asia'), ('GE', 'asia'),
  ('AM', 'asia'), ('SA', 'asia'), ('AE', 'asia'), ('IL', 'asia'),
  ('TR', 'asia'), ('IR', 'asia'), ('IQ', 'asia'), ('JO', 'asia'),
  ('LB', 'asia'), ('KW', 'asia'), ('QA', 'asia'), ('BH', 'asia'),
  ('OM', 'asia'), ('YE', 'asia'), ('AF', 'asia'),
  -- Africa
  ('NG', 'africa'), ('ZA', 'africa'), ('EG', 'africa'), ('KE', 'africa'),
  ('ET', 'africa'), ('TZ', 'africa'), ('UG', 'africa'), ('GH', 'africa'),
  ('MA', 'africa'), ('DZ', 'africa'), ('TN', 'africa'), ('LY', 'africa'),
  ('SD', 'africa'), ('AO', 'africa'), ('MZ', 'africa'), ('ZW', 'africa'),
  ('ZM', 'africa'), ('MW', 'africa'), ('RW', 'africa'), ('SN', 'africa'),
  ('CI', 'africa'), ('CM', 'africa'), ('MG', 'africa'), ('BF', 'africa'),
  ('ML', 'africa'), ('NE', 'africa'), ('TD', 'africa'), ('SO', 'africa'),
  ('CD', 'africa'), ('CG', 'africa'), ('GA', 'africa'), ('BJ', 'africa'),
  ('TG', 'africa'), ('SL', 'africa'), ('LR', 'africa'), ('MR', 'africa'),
  ('GM', 'africa'), ('GW', 'africa'), ('CV', 'africa'), ('GN', 'africa'),
  ('ER', 'africa'), ('DJ', 'africa'), ('KM', 'africa'), ('MU', 'africa'),
  ('SC', 'africa'), ('SS', 'africa'), ('BW', 'africa'), ('NA', 'africa'),
  ('SZ', 'africa'), ('LS', 'africa'),
  -- Oceania
  ('AU', 'oceania'), ('NZ', 'oceania'), ('FJ', 'oceania'), ('PG', 'oceania'),
  ('NC', 'oceania'), ('VU', 'oceania'), ('WS', 'oceania'), ('TO', 'oceania'),
  ('FM', 'oceania'), ('PW', 'oceania'), ('MH', 'oceania'), ('KI', 'oceania'),
  ('NR', 'oceania'), ('TV', 'oceania'), ('SB', 'oceania'), ('PF', 'oceania'),
  ('GU', 'oceania'), ('AS', 'oceania'), ('MP', 'oceania'), ('CK', 'oceania'),
  ('NU', 'oceania'), ('TK', 'oceania'), ('WF', 'oceania');
