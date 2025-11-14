-- =====================================================
-- Migration Script: From Basic Schema to Complete Backend
-- =====================================================
-- This script migrates data from the old basic schema to the new comprehensive schema
-- Run this after executing the complete schema and before adding sample data

-- NOTE: This migration assumes you're running it on a database with the old schema
-- Adjust table names and field mappings as needed based on your current implementation

-- =====================================================
-- Step 1: Backup Old Data (Optional)
-- =====================================================

-- Create backup tables (optional - uncomment if you want backups)
/*
CREATE TABLE profiles_backup AS SELECT * FROM profiles;
CREATE TABLE events_backup AS SELECT * FROM events;
CREATE TABLE announcements_backup AS SELECT * FROM announcements;
CREATE TABLE resources_backup AS SELECT * FROM resources;
*/

-- =====================================================
-- Step 2: Migrate Profiles Data
-- =====================================================

-- The new profiles table has a different structure. Map old fields to new ones.
-- First, let's rename the old profiles table temporarily
ALTER TABLE profiles RENAME TO profiles_old;

-- Create the new profiles table structure (this is already done in the main schema)
-- Now migrate data from old to new

INSERT INTO profiles (
  id,
  username,
  full_name,
  phone,
  bio,
  role,
  created_at,
  updated_at
)
SELECT
  id,
  -- Use email as username if no username exists, or generate one
  CASE
    WHEN email IS NOT NULL AND email != '' THEN SPLIT_PART(email, '@', 1)
    ELSE 'user_' || SUBSTRING(id::TEXT, 1, 8)
  END as username,
  -- Map old 'name' to 'full_name'
  name as full_name,
  phone,
  bio,
  -- Map old 'position' to new 'role' with defaults
  CASE
    WHEN LOWER(position) IN ('president', 'vice president', 'treasurer', 'secretary') THEN 'officer'
    WHEN LOWER(position) IN ('advisor', 'teacher') THEN 'advisor'
    ELSE 'member'
  END as role,
  created_at,
  updated_at
FROM profiles_old;

-- =====================================================
-- Step 3: Migrate Events Data
-- =====================================================

-- Rename old events table temporarily
ALTER TABLE events RENAME TO events_old;

-- Insert data into new events table
INSERT INTO events (
  id,
  title,
  description,
  location,
  category,
  start_time,
  end_time,
  is_public,
  status,
  attendee_count,
  created_at,
  updated_at
)
SELECT
  id,
  title,
  description,
  location,
  -- Map old category to new category structure
  CASE
    WHEN category IS NOT NULL THEN category
    ELSE 'general'
  END as category,
  -- Convert old date and time to timestamp with timezone
  (date || ' ' || COALESCE(time, '09:00:00'))::timestamp with time zone as start_time,
  -- Estimate end_time (assume 2 hours duration)
  (date || ' ' || COALESCE(time, '09:00:00'))::timestamp with time zone + INTERVAL '2 hours' as end_time,
  true as is_public,
  CASE
    WHEN date < CURRENT_DATE THEN 'completed'
    WHEN date = CURRENT_DATE THEN 'ongoing'
    ELSE 'upcoming'
  END as status,
  COALESCE(attendees, 0) as attendee_count,
  created_at,
  updated_at
FROM events_old;

-- Update organizer_id - you'll need to set this appropriately based on your chapter structure
-- This is a placeholder - you may need to update based on your specific needs
UPDATE events SET organizer_id = (
  SELECT id FROM profiles WHERE role = 'officer' LIMIT 1
) WHERE organizer_id IS NULL;

-- =====================================================
-- Step 4: Migrate Announcements to Posts
-- =====================================================

-- Rename old announcements table temporarily
ALTER TABLE announcements RENAME TO announcements_old;

-- Insert announcements as posts in the new system
INSERT INTO posts (
  id,
  author_id,
  title,
  content,
  type,
  visibility,
  like_count,
  created_at,
  updated_at
)
SELECT
  id,
  -- Find an author profile for the announcement
  (SELECT id FROM profiles WHERE role = 'officer' LIMIT 1) as author_id,
  title,
  content,
  -- Map old categories to new post types
  CASE
    WHEN LOWER(category) = 'achievement' THEN 'achievement'
    WHEN LOWER(category) = 'announcement' THEN 'announcement'
    WHEN LOWER(category) = 'reminder' THEN 'announcement'
    WHEN LOWER(category) = 'update' THEN 'update'
    ELSE 'post'
  END as type,
  'public' as visibility,
  COALESCE(likes, 0) as like_count,
  created_at,
  updated_at
FROM announcements_old;

-- =====================================================
-- Step 5: Migrate Resources Data
-- =====================================================

-- Rename old resources table temporarily
ALTER TABLE resources RENAME TO resources_old;

-- First, create basic resource categories if they don't exist
INSERT INTO resource_categories (name, description, sort_order) VALUES
  ('Guides', 'Educational guides and tutorials', 1),
  ('Templates', 'Document templates and forms', 2),
  ('Presentations', 'Slide decks and presentation materials', 3),
  ('Documents', 'General documents and files', 4)
ON CONFLICT (name) DO NOTHING;

-- Insert resources into new table
INSERT INTO resources (
  id,
  title,
  description,
  category_id,
  file_url,
  file_name,
  file_type,
  file_size,
  download_count,
  is_public,
  created_at,
  updated_at
)
SELECT
  id,
  title,
  description,
  -- Map old category to new resource category
  (SELECT id FROM resource_categories WHERE
   CASE
     WHEN LOWER(category) = 'guide' THEN name = 'Guides'
     WHEN LOWER(category) = 'template' THEN name = 'Templates'
     WHEN LOWER(category) = 'presentation' THEN name = 'Presentations'
     WHEN LOWER(category) = 'document' THEN name = 'Documents'
     ELSE name = 'Documents'
   END
  ) as category_id,
  url as file_url,
  title as file_name, -- Use title as filename since original filename not available
  file_type,
  -- Convert size string to bytes (basic conversion)
  CASE
    WHEN size LIKE '%MB' THEN (CAST(SPLIT_PART(size, ' ', 1) AS NUMERIC) * 1024 * 1024)::bigint
    WHEN size LIKE '%KB' THEN (CAST(SPLIT_PART(size, ' ', 1) AS NUMERIC) * 1024)::bigint
    WHEN size LIKE '%GB' THEN (CAST(SPLIT_PART(size, ' ', 1) AS NUMERIC) * 1024 * 1024 * 1024)::bigint
    ELSE 1024::bigint -- Default 1KB
  END as file_size,
  COALESCE(downloads, 0) as download_count,
  true as is_public,
  created_at,
  updated_at
FROM resources_old;

-- Set uploader_id for resources (you may need to adjust this)
UPDATE resources SET uploader_id = (
  SELECT id FROM profiles WHERE role = 'officer' LIMIT 1
) WHERE uploader_id IS NULL;

-- =====================================================
-- Step 6: Create Default Chapter and Memberships
-- =====================================================

-- Create a default chapter if none exists
INSERT INTO chapters (id, name, description, is_active, created_at) VALUES
  (gen_random_uuid(), 'Default Chapter', 'Default FBLA chapter', true, NOW())
ON CONFLICT DO NOTHING;

-- Assign all users to the default chapter
INSERT INTO chapter_memberships (user_id, chapter_id, role, joined_at, is_active)
SELECT
  p.id,
  (SELECT id FROM chapters WHERE name = 'Default Chapter' LIMIT 1),
  CASE
    WHEN p.role = 'advisor' THEN 'advisor'
    WHEN p.role = 'officer' THEN 'officer'
    ELSE 'member'
  END,
  p.created_at,
  true
FROM profiles p
WHERE p.id NOT IN (
  SELECT DISTINCT user_id FROM chapter_memberships
);

-- =====================================================
-- Step 7: Clean Up
-- =====================================================

-- Drop old tables (optional - uncomment when you're sure migration is successful)
/*
DROP TABLE profiles_old;
DROP TABLE events_old;
DROP TABLE announcements_old;
DROP TABLE resources_old;
*/

-- =====================================================
-- Step 8: Create Basic Sample Data for New Features
-- =====================================================

-- Insert some sample achievements
INSERT INTO achievements (name, description, icon, points, type, criteria) VALUES
  ('First Post', 'Create your first post', '📝', 10, 'automatic', '{"post_count": 1}'),
  ('Social Butterfly', 'Follow 10 other users', '🦋', 25, 'automatic', '{"following_count": 10}'),
  ('Event Attendee', 'Attend 5 events', '📅', 50, 'automatic', '{"attended_events": 5}'),
  ('Resource Contributor', 'Upload 3 resources', '📚', 30, 'automatic', '{"uploaded_resources": 3}'),
  ('Engaged Member', 'Get 50 likes on your posts', '❤️', 100, 'automatic', '{"total_likes_received": 50}')
ON CONFLICT (name) DO NOTHING;

-- Create some initial notifications for users
INSERT INTO notifications (user_id, type, title, message, data, is_read, created_at)
SELECT
  p.id,
  'system',
  'Welcome to the New FBLA Connect!',
  'Your account has been migrated to our enhanced platform with new features like posts, events, resources, and more!',
  '{"migration_complete": true}',
  false,
  NOW()
FROM profiles p
WHERE p.id NOT IN (
  SELECT DISTINCT user_id FROM notifications WHERE type = 'system' AND title = 'Welcome to the New FBLA Connect!'
);

-- =====================================================
-- Migration Complete
-- =====================================================

-- Verify migration results
/*
SELECT 'Profiles' as table_name, COUNT(*) as count FROM profiles
UNION ALL
SELECT 'Events', COUNT(*) FROM events
UNION ALL
SELECT 'Posts', COUNT(*) FROM posts
UNION ALL
SELECT 'Resources', COUNT(*) FROM resources
UNION ALL
SELECT 'User Settings', COUNT(*) FROM user_settings
UNION ALL
SELECT 'Chapter Memberships', COUNT(*) FROM chapter_memberships;
*/