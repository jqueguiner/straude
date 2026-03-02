
-- =============================================
-- Migration: fix_schema_alignment
-- Aligns DB schema with straude-specs-v1.md
-- =============================================

-- Step 1: Clean test data (FK-safe order)
DELETE FROM comments;
DELETE FROM kudos;
DELETE FROM likes;
DELETE FROM posts;
DELETE FROM daily_usage;
DELETE FROM cli_auth_codes;
DELETE FROM follows;
DELETE FROM users;

-- Step 2: Drop likes table (not in spec, duplicate of kudos, no RLS)
DROP TABLE IF EXISTS likes CASCADE;

-- Step 3: Fix users table
-- 3a: Drop clerk_id column and related objects
DROP INDEX IF EXISTS idx_users_clerk_id;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_clerk_id_key;
ALTER TABLE users DROP COLUMN IF EXISTS clerk_id;

-- 3b: Make columns nullable per spec
ALTER TABLE users ALTER COLUMN username DROP NOT NULL;
ALTER TABLE users ALTER COLUMN country DROP NOT NULL;
ALTER TABLE users ALTER COLUMN region DROP NOT NULL;

-- 3c: Add FK to auth.users(id) with CASCADE delete
ALTER TABLE users ADD CONSTRAINT users_auth_id_fkey
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 3d: Fix username index to be partial (only index non-null usernames)
DROP INDEX IF EXISTS idx_users_username;
CREATE INDEX idx_users_username ON users(username) WHERE username IS NOT NULL;

-- Step 4: Add title column to posts
ALTER TABLE posts ADD COLUMN title TEXT;
ALTER TABLE posts ADD CONSTRAINT posts_title_check CHECK (char_length(title) <= 100);

-- Step 5: Fix daily_usage - add missing columns
ALTER TABLE daily_usage ADD COLUMN raw_hash TEXT;
ALTER TABLE daily_usage ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Add updated_at trigger for daily_usage
CREATE TRIGGER update_daily_usage_updated_at
  BEFORE UPDATE ON daily_usage
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 6: Fix kudos - make columns NOT NULL
ALTER TABLE kudos ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE kudos ALTER COLUMN post_id SET NOT NULL;
ALTER TABLE kudos ALTER COLUMN created_at SET NOT NULL;

-- Step 7: Add country_name to countries_to_regions
ALTER TABLE countries_to_regions ADD COLUMN country_name TEXT;

UPDATE countries_to_regions SET country_name = v.name
FROM (VALUES
  ('US', 'United States'), ('CA', 'Canada'), ('MX', 'Mexico'),
  ('GT', 'Guatemala'), ('BZ', 'Belize'), ('SV', 'El Salvador'),
  ('HN', 'Honduras'), ('NI', 'Nicaragua'), ('CR', 'Costa Rica'),
  ('PA', 'Panama'), ('CU', 'Cuba'), ('JM', 'Jamaica'),
  ('HT', 'Haiti'), ('DO', 'Dominican Republic'), ('TT', 'Trinidad and Tobago'),
  ('BB', 'Barbados'), ('BS', 'Bahamas'), ('PR', 'Puerto Rico'),
  ('BR', 'Brazil'), ('AR', 'Argentina'), ('CL', 'Chile'),
  ('CO', 'Colombia'), ('PE', 'Peru'), ('VE', 'Venezuela'),
  ('EC', 'Ecuador'), ('BO', 'Bolivia'), ('PY', 'Paraguay'),
  ('UY', 'Uruguay'), ('GY', 'Guyana'), ('SR', 'Suriname'),
  ('GB', 'United Kingdom'), ('DE', 'Germany'), ('FR', 'France'),
  ('ES', 'Spain'), ('IT', 'Italy'), ('NL', 'Netherlands'),
  ('PL', 'Poland'), ('SE', 'Sweden'), ('NO', 'Norway'),
  ('DK', 'Denmark'), ('FI', 'Finland'), ('CH', 'Switzerland'),
  ('AT', 'Austria'), ('BE', 'Belgium'), ('IE', 'Ireland'),
  ('PT', 'Portugal'), ('CZ', 'Czechia'), ('RO', 'Romania'),
  ('HU', 'Hungary'), ('UA', 'Ukraine'), ('GR', 'Greece'),
  ('HR', 'Croatia'), ('SK', 'Slovakia'), ('BG', 'Bulgaria'),
  ('RS', 'Serbia'), ('LT', 'Lithuania'), ('LV', 'Latvia'),
  ('EE', 'Estonia'), ('SI', 'Slovenia'), ('IS', 'Iceland'),
  ('LU', 'Luxembourg'), ('MT', 'Malta'),
  ('CN', 'China'), ('JP', 'Japan'), ('KR', 'South Korea'),
  ('IN', 'India'), ('SG', 'Singapore'), ('ID', 'Indonesia'),
  ('TH', 'Thailand'), ('VN', 'Vietnam'), ('MY', 'Malaysia'),
  ('PH', 'Philippines'), ('TW', 'Taiwan'), ('HK', 'Hong Kong'),
  ('IL', 'Israel'), ('AE', 'United Arab Emirates'), ('SA', 'Saudi Arabia'),
  ('PK', 'Pakistan'), ('BD', 'Bangladesh'), ('LK', 'Sri Lanka'),
  ('NP', 'Nepal'), ('KZ', 'Kazakhstan'), ('UZ', 'Uzbekistan'),
  ('MM', 'Myanmar'), ('KH', 'Cambodia'), ('LA', 'Laos'),
  ('NG', 'Nigeria'), ('ZA', 'South Africa'), ('EG', 'Egypt'),
  ('KE', 'Kenya'), ('GH', 'Ghana'), ('TZ', 'Tanzania'),
  ('ET', 'Ethiopia'), ('MA', 'Morocco'), ('TN', 'Tunisia'),
  ('DZ', 'Algeria'), ('UG', 'Uganda'), ('RW', 'Rwanda'),
  ('SN', 'Senegal'), ('CI', 'Ivory Coast'), ('CM', 'Cameroon'),
  ('MZ', 'Mozambique'),
  ('AU', 'Australia'), ('NZ', 'New Zealand'), ('FJ', 'Fiji'),
  ('PG', 'Papua New Guinea'), ('WS', 'Samoa'), ('TO', 'Tonga')
) AS v(code, name)
WHERE countries_to_regions.country_code = v.code;

-- Fallback: use country_code as name for any rows not in the list above
UPDATE countries_to_regions SET country_name = country_code WHERE country_name IS NULL;

ALTER TABLE countries_to_regions ALTER COLUMN country_name SET NOT NULL;
;
