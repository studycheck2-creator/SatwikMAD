-- =====================================================
-- Test Queries for Complete Supabase Backend
-- =====================================================
-- This file contains test queries to verify the implementation
-- Run these after setting up the complete schema

-- =====================================================
-- Test Table Creation
-- =====================================================

-- Check if all tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Expected tables:
-- achievements, announcements, chapter_memberships, chapters, comments, event_feedback,
-- event_registrations, events, follows, likes, bookmarks, media, message_threads,
-- messages, notifications, points, leaderboards, profiles, resource_categories,
-- resource_downloads, resource_ratings, resources, user_settings, user_achievements

-- =====================================================
-- Test RLS Policies
-- =====================================================

-- Check if RLS is enabled on all tables
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND table_name NOT LIKE 'pg_%'
ORDER BY tablename;

-- Check policy count per table
SELECT
  schemaname,
  tablename,
  COUNT(policyname) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY schemaname, tablename
ORDER BY tablename;

-- =====================================================
-- Test Indexes
-- =====================================================

-- Check important indexes exist
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND (
    tablename = 'profiles' OR
    tablename = 'posts' OR
    tablename = 'events' OR
    tablename = 'comments' OR
    tablename = 'likes' OR
    tablename = 'notifications'
  )
ORDER BY tablename, indexname;

-- =====================================================
-- Test Triggers
-- =====================================================

-- Check if triggers exist
SELECT
  event_object_table as table_name,
  trigger_name,
  event_manipulation as event_type,
  action_timing as timing,
  action_condition as condition,
  action_statement as function
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY table_name, trigger_name;

-- =====================================================
-- Test Storage Buckets
-- =====================================================

-- Check storage buckets
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
ORDER BY id;

-- Expected buckets:
-- profile-images, post-media, event-media, resources, temp-uploads

-- Check storage policies
SELECT bucket_id, policy_name, definition
FROM storage.policies
ORDER BY bucket_id, policy_name;

-- =====================================================
-- Test Basic CRUD Operations
-- =====================================================

-- Test Profile Creation (simulate user signup)
INSERT INTO profiles (id, username, full_name, role)
VALUES ('00000000-0000-0000-0000-000000000001', 'testuser', 'Test User', 'member');

-- Test User Settings Creation (should be auto-created by trigger)
SELECT * FROM user_settings WHERE id = '00000000-0000-0000-0000-000000000001';

-- Test Chapter Creation
INSERT INTO chapters (id, name, description, school_name, location)
VALUES ('00000000-0000-0000-0000-000000000002', 'Test Chapter', 'A test chapter', 'Test High School', 'Test City');

-- Test Chapter Membership
INSERT INTO chapter_memberships (user_id, chapter_id, role)
VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'member');

-- Test Post Creation
INSERT INTO posts (author_id, title, content, type, visibility)
VALUES ('00000000-0000-0000-0000-000000000001', 'Test Post', 'This is a test post', 'post', 'public');

-- Test Event Creation
INSERT INTO events (title, description, organizer_id, location, start_time, end_time)
VALUES ('Test Event', 'A test event', '00000000-0000-0000-0000-000000000001', 'Test Location',
        NOW() + INTERVAL '1 day', NOW() + INTERVAL '2 days');

-- Test Resource Category Creation
INSERT INTO resource_categories (name, description, sort_order)
VALUES ('Test Category', 'A test resource category', 1);

-- =====================================================
-- Test Relationships and Constraints
-- =====================================================

-- Test foreign key constraints (this should fail)
-- INSERT INTO posts (author_id, title, content, type, visibility)
-- VALUES ('00000000-0000-0000-0000-000000000999', 'Invalid Post', 'This should fail', 'post', 'public');

-- Test check constraints (this should fail)
-- INSERT INTO posts (author_id, title, content, type, visibility)
-- VALUES ('00000000-0000-0000-0000-000000000001', 'Invalid Type', 'This should fail', 'invalid_type', 'public');

-- Test unique constraints (this should fail if username exists)
-- INSERT INTO profiles (id, username, full_name, role)
-- VALUES ('00000000-0000-0000-0000-000000000003', 'testuser', 'Another User', 'member');

-- =====================================================
-- Test Functions
-- =====================================================

-- Test update_timestamps function
UPDATE profiles SET bio = 'Updated bio' WHERE id = '00000000-0000-0000-0000-000000000001';
SELECT updated_at FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';

-- Test notification functions
INSERT INTO notifications (user_id, type, title, message)
VALUES ('00000000-0000-0000-0000-000000000001', 'system', 'Test Notification', 'This is a test');

-- Test points system
INSERT INTO points (user_id, amount, reason, source_type)
VALUES ('00000000-0000-0000-0000-000000000001', 10, 'Test points', 'manual');

-- =====================================================
-- Test Complex Queries
-- =====================================================

-- Test user feed query
SELECT
  p.id,
  p.title,
  p.content,
  p.created_at,
  pr.username as author_username,
  pr.full_name as author_name,
  p.like_count,
  p.comment_count
FROM posts p
JOIN profiles pr ON p.author_id = pr.id
WHERE p.visibility = 'public'
  AND p.is_draft = false
ORDER BY p.created_at DESC
LIMIT 10;

-- Test event with registrations query
SELECT
  e.id,
  e.title,
  e.start_time,
  e.attendee_count,
  COUNT(er.id) as registered_count
FROM events e
LEFT JOIN event_registrations er ON e.id = er.event_id
WHERE e.start_time > NOW()
GROUP BY e.id, e.title, e.start_time, e.attendee_count
ORDER BY e.start_time;

-- Test user statistics query
SELECT
  COUNT(DISTINCT p.id) as post_count,
  COUNT(DISTINCT c.id) as comment_count,
  COALESCE(SUM(p.like_count), 0) as total_likes_received,
  COALESCE(SUM(po.amount), 0) as total_points
FROM profiles pr
LEFT JOIN posts p ON pr.id = p.author_id
LEFT JOIN comments c ON pr.id = c.author_id
LEFT JOIN points po ON pr.id = po.user_id
WHERE pr.id = '00000000-0000-0000-0000-000000000001';

-- =====================================================
-- Test Data Integrity
-- =====================================================

-- Check for orphaned records (should return none)
SELECT 'posts without authors' as issue, COUNT(*) as count
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id
WHERE pr.id IS NULL

UNION ALL

SELECT 'comments without posts' as issue, COUNT(*) as count
FROM comments c
LEFT JOIN posts p ON c.post_id = p.id
WHERE p.id IS NULL

UNION ALL

SELECT 'likes without users' as issue, COUNT(*) as count
FROM likes l
LEFT JOIN profiles p ON l.user_id = p.id
WHERE p.id IS NULL;

-- =====================================================
-- Performance Test Queries
-- =====================================================

-- Test index usage (should use index on posts.created_at)
EXPLAIN ANALYZE
SELECT * FROM posts
ORDER BY created_at DESC
LIMIT 20;

-- Test index usage (should use index on likes.user_id)
EXPLAIN ANALYZE
SELECT * FROM likes
WHERE user_id = '00000000-0000-0000-0000-000000000001';

-- Test join performance
EXPLAIN ANALYZE
SELECT
  p.id, p.content, p.created_at,
  pr.username, pr.full_name,
  COUNT(l.id) as like_count
FROM posts p
JOIN profiles pr ON p.author_id = pr.id
LEFT JOIN likes l ON p.id = l.target_id AND l.target_type = 'post'
WHERE p.visibility = 'public'
GROUP BY p.id, p.content, p.created_at, pr.username, pr.full_name
ORDER BY p.created_at DESC
LIMIT 50;

-- =====================================================
-- Cleanup Test Data
-- =====================================================

-- Remove test data (uncomment to clean up)
/*
DELETE FROM points WHERE user_id = '00000000-0000-0000-0000-000000000001';
DELETE FROM notifications WHERE user_id = '00000000-0000-0000-0000-000000000001';
DELETE FROM events WHERE organizer_id = '00000000-0000-0000-0000-000000000001';
DELETE FROM posts WHERE author_id = '00000000-0000-0000-0000-000000000001';
DELETE FROM chapter_memberships WHERE user_id = '00000000-0000-0000-0000-000000000001';
DELETE FROM resource_categories WHERE name = 'Test Category';
DELETE FROM chapters WHERE id = '00000000-0000-0000-0000-000000000002';
DELETE FROM user_settings WHERE id = '00000000-0000-0000-0000-000000000001';
DELETE FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
*/

-- =====================================================
-- Summary Test
-- =====================================================

-- Final verification query
SELECT
  'Tables' as component,
  COUNT(*) as count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'

UNION ALL

SELECT
  'Policies',
  COUNT(*)
FROM pg_policies
WHERE schemaname = 'public'

UNION ALL

SELECT
  'Triggers',
  COUNT(*)
FROM information_schema.triggers
WHERE trigger_schema = 'public'

UNION ALL

SELECT
  'Storage Buckets',
  COUNT(*)
FROM storage.buckets;

-- Expected results (approximately):
-- Tables: 26
-- Policies: 60+
-- Triggers: 10+
-- Storage Buckets: 5