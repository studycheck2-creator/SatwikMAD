-- =====================================================
-- FIXED SUPABASE BACKEND DEPLOYMENT SCRIPT
-- =====================================================
-- This script handles the correct order of table creation
-- RUN THIS ONCE in your Supabase SQL Editor

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- STEP 1: DROP TRIGGERS AND FUNCTIONS FIRST
-- =====================================================

-- Drop triggers first (they reference tables)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS create_user_settings_trigger ON profiles;
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
DROP TRIGGER IF EXISTS update_user_settings_updated_at ON user_settings;
DROP TRIGGER IF EXISTS update_chapters_updated_at ON chapters;
DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
DROP TRIGGER IF EXISTS update_comments_updated_at ON comments;
DROP TRIGGER IF EXISTS update_events_updated_at ON events;
DROP TRIGGER IF EXISTS update_announcements_updated_at ON announcements;
DROP TRIGGER IF EXISTS update_resources_updated_at ON resources;

-- Drop functions
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS create_user_settings() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_post_counts() CASCADE;
DROP FUNCTION IF EXISTS update_like_counts() CASCADE;

-- =====================================================
-- STEP 2: CREATE CORE TABLES WITHOUT REFERENCES FIRST
-- =====================================================

-- Profiles table (no foreign key constraints initially)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  website TEXT,
  location TEXT,
  phone TEXT,
  grade TEXT,
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'officer', 'admin', 'super_admin')),
  is_active BOOLEAN DEFAULT true,
  email_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User settings table
CREATE TABLE IF NOT EXISTS user_settings (
  id UUID PRIMARY KEY,
  push_notifications BOOLEAN DEFAULT true,
  email_notifications BOOLEAN DEFAULT true,
  theme TEXT DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'auto')),
  language TEXT DEFAULT 'en',
  timezone TEXT DEFAULT 'UTC',
  privacy_profile_public BOOLEAN DEFAULT true,
  privacy_show_email BOOLEAN DEFAULT false,
  privacy_show_phone BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chapters table
CREATE TABLE IF NOT EXISTS chapters (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  school_name TEXT,
  location TEXT,
  website TEXT,
  logo_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Resource categories table
CREATE TABLE IF NOT EXISTS resource_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  parent_id UUID,
  icon TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Achievements table
CREATE TABLE IF NOT EXISTS achievements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  icon TEXT,
  points INTEGER DEFAULT 0,
  type TEXT DEFAULT 'automatic' CHECK (type IN ('automatic', 'manual', 'milestone')),
  criteria JSONB,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- STEP 3: CREATE TABLES WITH FOREIGN KEYS
-- =====================================================

-- Chapter memberships
CREATE TABLE IF NOT EXISTS chapter_memberships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  chapter_id UUID,
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'officer', 'advisor')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  left_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true,
  UNIQUE(user_id, chapter_id)
);

-- Posts table
CREATE TABLE IF NOT EXISTS posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id UUID,
  chapter_id UUID,
  title TEXT,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'post' CHECK (type IN ('post', 'announcement', 'achievement', 'update')),
  visibility TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'chapter', 'private')),
  media_urls TEXT[], -- Array of media file URLs
  tags TEXT[],
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  share_count INTEGER DEFAULT 0,
  is_pinned BOOLEAN DEFAULT false,
  is_draft BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Media table
CREATE TABLE IF NOT EXISTS media (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  uploader_id UUID,
  post_id UUID,
  filename TEXT NOT NULL,
  original_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  file_path TEXT NOT NULL,
  thumbnail_url TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Comments table
CREATE TABLE IF NOT EXISTS comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id UUID,
  post_id UUID,
  parent_id UUID,
  content TEXT NOT NULL,
  like_count INTEGER DEFAULT 0,
  reply_count INTEGER DEFAULT 0,
  is_edited BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Likes table
CREATE TABLE IF NOT EXISTS likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment', 'event', 'resource')),
  target_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, target_type, target_id)
);

-- Social interaction tables
CREATE TABLE IF NOT EXISTS follows (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id UUID,
  following_id UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(follower_id, following_id),
  CHECK(follower_id != following_id)
);

CREATE TABLE IF NOT EXISTS shares (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  post_id UUID,
  caption TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

CREATE TABLE IF NOT EXISTS mentions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  mentioned_user_id UUID,
  mentioner_id UUID,
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment')),
  target_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bookmarks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'event', 'resource')),
  target_id UUID NOT NULL,
  folder TEXT DEFAULT 'default',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, target_type, target_id)
);

-- Event tables
CREATE TABLE IF NOT EXISTS events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  chapter_id UUID,
  organizer_id UUID,
  category TEXT DEFAULT 'general' CHECK (category IN ('meeting', 'competition', 'workshop', 'social', 'fundraiser', 'community_service', 'general')),
  location TEXT,
  virtual_meeting_url TEXT,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  max_attendees INTEGER,
  registration_deadline TIMESTAMP WITH TIME ZONE,
  image_url TEXT,
  is_public BOOLEAN DEFAULT true,
  requires_registration BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
  attendee_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK(end_time > start_time)
);

CREATE TABLE IF NOT EXISTS event_registrations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID,
  user_id UUID,
  registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  attended BOOLEAN DEFAULT false,
  notes TEXT,
  UNIQUE(event_id, user_id)
);

CREATE TABLE IF NOT EXISTS event_feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID,
  user_id UUID,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  feedback TEXT,
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- Communication tables
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'mention', 'event_reminder', 'announcement', 'achievement', 'system')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS message_threads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  participant1_id UUID,
  participant2_id UUID,
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_message_preview TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK(participant1_id != participant2_id),
  UNIQUE(participant1_id, participant2_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  thread_id UUID,
  sender_id UUID,
  content TEXT NOT NULL,
  media_url TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS announcements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id UUID,
  chapter_id UUID,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  is_published BOOLEAN DEFAULT false,
  publish_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Resource tables
CREATE TABLE IF NOT EXISTS resources (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  category_id UUID,
  chapter_id UUID,
  uploader_id UUID,
  file_url TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  thumbnail_url TEXT,
  download_count INTEGER DEFAULT 0,
  rating_average DECIMAL(3,2) DEFAULT 0.00,
  rating_count INTEGER DEFAULT 0,
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS resource_downloads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  resource_id UUID,
  user_id UUID,
  downloaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS resource_ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  resource_id UUID,
  user_id UUID,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(resource_id, user_id)
);

-- Gamification tables
CREATE TABLE IF NOT EXISTS user_achievements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  achievement_id UUID,
  earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

CREATE TABLE IF NOT EXISTS points (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL,
  source_type TEXT CHECK (source_type IN ('post', 'comment', 'event_attendance', 'achievement', 'manual')),
  source_id UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leaderboards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('points', 'posts', 'likes', 'event_attendance')),
  period TEXT DEFAULT 'all_time' CHECK (period IN ('daily', 'weekly', 'monthly', 'all_time')),
  user_id UUID,
  score INTEGER NOT NULL,
  rank_position INTEGER,
  calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(type, period, user_id)
);

-- =====================================================
-- STEP 4: ADD FOREIGN KEY CONSTRAINTS NOW THAT TABLES EXIST
-- =====================================================

-- Add foreign key constraints
DO $$
BEGIN
    -- Profiles foreign key
    ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- User settings foreign key
    ALTER TABLE user_settings ADD CONSTRAINT user_settings_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Chapters created_by foreign key
    ALTER TABLE chapters ADD CONSTRAINT chapters_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Resource categories parent foreign key
    ALTER TABLE resource_categories ADD CONSTRAINT resource_categories_parent_fkey FOREIGN KEY (parent_id) REFERENCES resource_categories(id);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Chapter memberships foreign keys
    ALTER TABLE chapter_memberships ADD CONSTRAINT chapter_memberships_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE chapter_memberships ADD CONSTRAINT chapter_memberships_chapter_fkey FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Posts foreign keys
    ALTER TABLE posts ADD CONSTRAINT posts_author_fkey FOREIGN KEY (author_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE posts ADD CONSTRAINT posts_chapter_fkey FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Media foreign keys
    ALTER TABLE media ADD CONSTRAINT media_uploader_fkey FOREIGN KEY (uploader_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE media ADD CONSTRAINT media_post_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Comments foreign keys
    ALTER TABLE comments ADD CONSTRAINT comments_author_fkey FOREIGN KEY (author_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE comments ADD CONSTRAINT comments_post_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;
    ALTER TABLE comments ADD CONSTRAINT comments_parent_fkey FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Likes foreign key
    ALTER TABLE likes ADD CONSTRAINT likes_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Follows foreign keys
    ALTER TABLE follows ADD CONSTRAINT follows_follower_fkey FOREIGN KEY (follower_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE follows ADD CONSTRAINT follows_following_fkey FOREIGN KEY (following_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Shares foreign keys
    ALTER TABLE shares ADD CONSTRAINT shares_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE shares ADD CONSTRAINT shares_post_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Mentions foreign keys
    ALTER TABLE mentions ADD CONSTRAINT mentions_mentioned_fkey FOREIGN KEY (mentioned_user_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE mentions ADD CONSTRAINT mentions_mentioner_fkey FOREIGN KEY (mentioner_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Bookmarks foreign key
    ALTER TABLE bookmarks ADD CONSTRAINT bookmarks_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Events foreign keys
    ALTER TABLE events ADD CONSTRAINT events_chapter_fkey FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE;
    ALTER TABLE events ADD CONSTRAINT events_organizer_fkey FOREIGN KEY (organizer_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Event registrations foreign keys
    ALTER TABLE event_registrations ADD CONSTRAINT event_registrations_event_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
    ALTER TABLE event_registrations ADD CONSTRAINT event_registrations_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Event feedback foreign keys
    ALTER TABLE event_feedback ADD CONSTRAINT event_feedback_event_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
    ALTER TABLE event_feedback ADD CONSTRAINT event_feedback_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Notifications foreign key
    ALTER TABLE notifications ADD CONSTRAINT notifications_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Message threads foreign keys
    ALTER TABLE message_threads ADD CONSTRAINT message_threads_participant1_fkey FOREIGN KEY (participant1_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE message_threads ADD CONSTRAINT message_threads_participant2_fkey FOREIGN KEY (participant2_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Messages foreign keys
    ALTER TABLE messages ADD CONSTRAINT messages_thread_fkey FOREIGN KEY (thread_id) REFERENCES message_threads(id) ON DELETE CASCADE;
    ALTER TABLE messages ADD CONSTRAINT messages_sender_fkey FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Announcements foreign keys
    ALTER TABLE announcements ADD CONSTRAINT announcements_author_fkey FOREIGN KEY (author_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE announcements ADD CONSTRAINT announcements_chapter_fkey FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Resources foreign keys
    ALTER TABLE resources ADD CONSTRAINT resources_category_fkey FOREIGN KEY (category_id) REFERENCES resource_categories(id);
    ALTER TABLE resources ADD CONSTRAINT resources_chapter_fkey FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE;
    ALTER TABLE resources ADD CONSTRAINT resources_uploader_fkey FOREIGN KEY (uploader_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Resource downloads foreign keys
    ALTER TABLE resource_downloads ADD CONSTRAINT resource_downloads_resource_fkey FOREIGN KEY (resource_id) REFERENCES resources(id) ON DELETE CASCADE;
    ALTER TABLE resource_downloads ADD CONSTRAINT resource_downloads_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Resource ratings foreign keys
    ALTER TABLE resource_ratings ADD CONSTRAINT resource_ratings_resource_fkey FOREIGN KEY (resource_id) REFERENCES resources(id) ON DELETE CASCADE;
    ALTER TABLE resource_ratings ADD CONSTRAINT resource_ratings_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- User achievements foreign keys
    ALTER TABLE user_achievements ADD CONSTRAINT user_achievements_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
    ALTER TABLE user_achievements ADD CONSTRAINT user_achievements_achievement_fkey FOREIGN KEY (achievement_id) REFERENCES achievements(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Points foreign key
    ALTER TABLE points ADD CONSTRAINT points_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    -- Leaderboards foreign key
    ALTER TABLE leaderboards ADD CONSTRAINT leaderboards_user_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- =====================================================
-- STEP 5: CREATE INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_full_name ON profiles(full_name);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

CREATE INDEX IF NOT EXISTS idx_chapter_memberships_user ON chapter_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_chapter_memberships_chapter ON chapter_memberships(chapter_id);

CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_chapter ON posts(chapter_id);
CREATE INDEX IF NOT EXISTS idx_posts_type ON posts(type);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON posts(visibility);

CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_comments_author ON comments(author_id);

CREATE INDEX IF NOT EXISTS idx_likes_user ON likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_target ON likes(target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON bookmarks(user_id);

CREATE INDEX IF NOT EXISTS idx_events_chapter ON events(chapter_id);
CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);

CREATE INDEX IF NOT EXISTS idx_event_registrations_event ON event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_user ON event_registrations(user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_resources_category ON resources(category_id);
CREATE INDEX IF NOT EXISTS idx_resources_chapter ON resources(chapter_id);
CREATE INDEX IF NOT EXISTS idx_resources_public ON resources(is_public);
CREATE INDEX IF NOT EXISTS idx_resources_created_at ON resources(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_points_user ON points(user_id);
CREATE INDEX IF NOT EXISTS idx_points_created_at ON points(created_at DESC);

-- =====================================================
-- STEP 6: CREATE FUNCTIONS AND TRIGGERS
-- =====================================================

-- Update timestamps function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at columns
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON user_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chapters_updated_at BEFORE UPDATE ON chapters FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_resources_updated_at BEFORE UPDATE ON resources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-create user profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, avatar_url)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create default user settings
CREATE OR REPLACE FUNCTION create_user_settings()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_settings (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER create_user_settings_trigger
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION create_user_settings();

-- =====================================================
-- STEP 7: ENABLE ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapter_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_downloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE points ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboards ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- STEP 8: CREATE RLS POLICIES
-- =====================================================

-- Profiles policies
CREATE POLICY "Users can view profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- User Settings policies
CREATE POLICY "Users can manage own settings" ON user_settings FOR ALL USING (auth.uid() = id);

-- Posts policies
CREATE POLICY "Users can view public posts" ON posts FOR SELECT USING (
  visibility = 'public' OR
  visibility = 'chapter' AND chapter_id IN (
    SELECT chapter_id FROM chapter_memberships
    WHERE user_id = auth.uid() AND is_active = true
  ) OR
  author_id = auth.uid()
);

CREATE POLICY "Users can create posts" ON posts FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY "Users can update own posts" ON posts FOR UPDATE USING (
  author_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND role IN ('officer', 'admin', 'super_admin')
  )
);

-- Events policies
CREATE POLICY "Users can view events" ON events FOR SELECT USING (
  is_public = true OR
  chapter_id IN (
    SELECT chapter_id FROM chapter_memberships
    WHERE user_id = auth.uid() AND is_active = true
  ) OR
  organizer_id = auth.uid()
);

CREATE POLICY "Users can create events" ON events FOR INSERT WITH CHECK (
  organizer_id = auth.uid()
);

-- Simplified policies for other tables
CREATE POLICY "Users can manage likes" ON likes FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users can manage follows" ON follows FOR ALL USING (follower_id = auth.uid());
CREATE POLICY "Users can manage bookmarks" ON bookmarks FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users can manage own notifications" ON notifications FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users can manage comments" ON comments FOR ALL USING (author_id = auth.uid());

-- =====================================================
-- STEP 9: CREATE STORAGE BUCKETS
-- =====================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('profile-images', 'profile-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('post-media', 'post-media', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/quicktime', 'application/pdf']),
  ('resources', 'resources', true, 104857600, ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('temp-uploads', 'temp-uploads', false, 104857600, NULL)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "Public can view profile images" ON storage.objects FOR SELECT USING (bucket_id = 'profile-images');
CREATE POLICY "Users can upload own profile image" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'profile-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- =====================================================
-- STEP 10: INSERT SAMPLE DATA
-- =====================================================

-- Create default chapter
INSERT INTO chapters (id, name, description, school_name, location, is_active)
VALUES ('00000000-0000-0000-0000-000000000001', 'Default FBLA Chapter', 'Default chapter for all members', 'Your High School', 'Your City', true)
ON CONFLICT (id) DO NOTHING;

-- Create sample achievements
INSERT INTO achievements (name, description, icon, points, type) VALUES
  ('First Post', 'Create your first post', '📝', 10, 'automatic'),
  ('Social Butterfly', 'Follow 10 other users', '🦋', 25, 'automatic'),
  ('Event Attendee', 'Attend 5 events', '📅', 50, 'automatic'),
  ('Resource Contributor', 'Upload 3 resources', '📚', 30, 'automatic')
ON CONFLICT (name) DO NOTHING;

-- Create resource categories
INSERT INTO resource_categories (name, description, sort_order) VALUES
  ('Guides', 'Educational guides and tutorials', 1),
  ('Templates', 'Document templates and forms', 2),
  ('Presentations', 'Slide decks and presentation materials', 3),
  ('Documents', 'General documents and files', 4)
ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- VERIFICATION
-- =====================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT '✅ FIXED Supabase Backend Deployment Complete!' as status,
       'All tables created with proper foreign key order, indexes added, RLS enabled, and sample data inserted' as details;