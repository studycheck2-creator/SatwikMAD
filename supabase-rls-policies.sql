-- =====================================================
-- Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS on all tables
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
-- Profile and User Management Policies
-- =====================================================

-- Profiles: Users can view all profiles, update only their own
CREATE POLICY "Users can view profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Admins can update any profile" ON profiles FOR UPDATE USING (
  auth.uid() = id OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- User Settings: Users can only access their own settings
CREATE POLICY "Users can manage own settings" ON user_settings FOR ALL USING (auth.uid() = id);

-- Chapters: Public read access, officers can manage their chapter
CREATE POLICY "Public can view chapters" ON chapters FOR SELECT USING (is_active = true);
CREATE POLICY "Chapter officers can manage chapter" ON chapters FOR ALL USING (
  EXISTS (
    SELECT 1 FROM chapter_memberships cm
    JOIN profiles p ON cm.user_id = p.id
    WHERE cm.chapter_id = id AND cm.user_id = auth.uid()
    AND cm.is_active = true AND p.role IN ('officer', 'admin', 'super_admin')
  )
);

-- Chapter Memberships: Users can view memberships, officers can manage
CREATE POLICY "Users can view chapter memberships" ON chapter_memberships FOR SELECT USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM chapter_memberships cm
    JOIN profiles p ON cm.user_id = p.id
    WHERE cm.chapter_id = chapter_memberships.chapter_id AND cm.user_id = auth.uid()
    AND cm.is_active = true AND p.role IN ('officer', 'admin', 'super_admin')
  )
);
CREATE POLICY "Users can manage own membership" ON chapter_memberships FOR ALL USING (user_id = auth.uid());

-- =====================================================
-- Content and Media Policies
-- =====================================================

-- Posts: Visibility-based access
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
CREATE POLICY "Users can delete own posts" ON posts FOR DELETE USING (author_id = auth.uid());

-- Media: Access based on associated content
CREATE POLICY "Users can view media" ON media FOR SELECT USING (
  post_id IN (
    SELECT id FROM posts WHERE
    visibility = 'public' OR
    author_id = auth.uid() OR
    (visibility = 'chapter' AND chapter_id IN (
      SELECT chapter_id FROM chapter_memberships
      WHERE user_id = auth.uid() AND is_active = true
    ))
  ) OR
  uploader_id = auth.uid()
);
CREATE POLICY "Users can upload media" ON media FOR INSERT WITH CHECK (uploader_id = auth.uid());
CREATE POLICY "Users can manage own media" ON media FOR ALL USING (uploader_id = auth.uid());

-- Comments: Access based on post visibility
CREATE POLICY "Users can view comments" ON comments FOR SELECT USING (
  post_id IN (
    SELECT id FROM posts WHERE
    visibility = 'public' OR
    author_id = auth.uid() OR
    (visibility = 'chapter' AND chapter_id IN (
      SELECT chapter_id FROM chapter_memberships
      WHERE user_id = auth.uid() AND is_active = true
    ))
  )
);
CREATE POLICY "Users can create comments" ON comments FOR INSERT WITH CHECK (author_id = auth.uid());
CREATE POLICY "Users can update own comments" ON comments FOR UPDATE USING (author_id = auth.uid());
CREATE POLICY "Users can delete own comments" ON comments FOR DELETE USING (author_id = auth.uid());

-- Likes: Users can like accessible content
CREATE POLICY "Users can manage likes" ON likes FOR ALL USING (user_id = auth.uid());

-- =====================================================
-- Social Interaction Policies
-- =====================================================

-- Follows: Users can manage their own follows
CREATE POLICY "Users can manage follows" ON follows FOR ALL USING (follower_id = auth.uid());
CREATE POLICY "Public can view follows" ON follows FOR SELECT USING (true);

-- Shares: Based on post visibility
CREATE POLICY "Users can view shares" ON shares FOR SELECT USING (
  post_id IN (
    SELECT id FROM posts WHERE
    visibility = 'public' OR
    author_id = auth.uid() OR
    (visibility = 'chapter' AND chapter_id IN (
      SELECT chapter_id FROM chapter_memberships
      WHERE user_id = auth.uid() AND is_active = true
    ))
  )
);
CREATE POLICY "Users can create shares" ON shares FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can manage own shares" ON shares FOR ALL USING (user_id = auth.uid());

-- Mentions: Users can manage mentions they make/receive
CREATE POLICY "Users can manage mentions" ON mentions FOR ALL USING (
  mentioner_id = auth.uid() OR mentioned_user_id = auth.uid()
);
CREATE POLICY "Public can view mentions" ON mentions FOR SELECT USING (
  mentioned_user_id = auth.uid() OR
  mentioner_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND role IN ('officer', 'admin', 'super_admin')
  )
);

-- Bookmarks: Personal management
CREATE POLICY "Users can manage bookmarks" ON bookmarks FOR ALL USING (user_id = auth.uid());

-- =====================================================
-- Event Management Policies
-- =====================================================

-- Events: Public and chapter-based access
CREATE POLICY "Users can view events" ON events FOR SELECT USING (
  is_public = true OR
  chapter_id IN (
    SELECT chapter_id FROM chapter_memberships
    WHERE user_id = auth.uid() AND is_active = true
  ) OR
  organizer_id = auth.uid()
);
CREATE POLICY "Officers can create events" ON events FOR INSERT WITH CHECK (
  organizer_id = auth.uid() AND (
    chapter_id IS NULL OR
    EXISTS (
      SELECT 1 FROM chapter_memberships cm
      JOIN profiles p ON cm.user_id = p.id
      WHERE cm.chapter_id = events.chapter_id AND cm.user_id = auth.uid()
      AND cm.is_active = true AND p.role IN ('officer', 'admin', 'super_admin')
    )
  )
);
CREATE POLICY "Organizers can manage events" ON events FOR UPDATE USING (
  organizer_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND role IN ('officer', 'admin', 'super_admin')
  )
);

-- Event Registrations: Users can manage their own registrations
CREATE POLICY "Users can view registrations" ON event_registrations FOR SELECT USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM events WHERE id = event_id AND organizer_id = auth.uid()
  ) OR
  EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND role IN ('officer', 'admin', 'super_admin')
  )
);
CREATE POLICY "Users can create registrations" ON event_registrations FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own registrations" ON event_registrations FOR UPDATE USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM events WHERE id = event_id AND organizer_id = auth.uid()
  )
);

-- Event Feedback: Only from registered attendees
CREATE POLICY "Users can manage feedback" ON event_feedback FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users can create feedback" ON event_feedback FOR INSERT WITH CHECK (
  user_id = auth.uid() AND
  EXISTS (SELECT 1 FROM event_registrations WHERE event_id = event_feedback.event_id AND user_id = auth.uid())
);

-- =====================================================
-- Communication Policies
-- =====================================================

-- Notifications: Users can only access their own notifications
CREATE POLICY "Users can manage own notifications" ON notifications FOR ALL USING (user_id = auth.uid());

-- Message Threads: Participants only
CREATE POLICY "Users can manage message threads" ON message_threads FOR ALL USING (
  participant1_id = auth.uid() OR participant2_id = auth.uid()
);

-- Messages: Thread participants only
CREATE POLICY "Users can view thread messages" ON messages FOR SELECT USING (
  thread_id IN (
    SELECT id FROM message_threads WHERE
    participant1_id = auth.uid() OR participant2_id = auth.uid()
  )
);
CREATE POLICY "Users can create messages" ON messages FOR INSERT WITH CHECK (
  sender_id = auth.uid() AND
  thread_id IN (
    SELECT id FROM message_threads WHERE
    participant1_id = auth.uid() OR participant2_id = auth.uid()
  )
);
CREATE POLICY "Users can update own messages" ON messages FOR UPDATE USING (sender_id = auth.uid());

-- Announcements: Based on chapter membership and roles
CREATE POLICY "Users can view announcements" ON announcements FOR SELECT USING (
  is_published = true AND (
    chapter_id IS NULL OR
    chapter_id IN (
      SELECT chapter_id FROM chapter_memberships
      WHERE user_id = auth.uid() AND is_active = true
    )
  )
);
CREATE POLICY "Officers can create announcements" ON announcements FOR INSERT WITH CHECK (
  author_id = auth.uid() AND (
    chapter_id IS NULL OR
    EXISTS (
      SELECT 1 FROM chapter_memberships cm
      JOIN profiles p ON cm.user_id = p.id
      WHERE cm.chapter_id = announcements.chapter_id AND cm.user_id = auth.uid()
      AND cm.is_active = true AND p.role IN ('officer', 'admin', 'super_admin')
    )
  )
);
CREATE POLICY "Authors can manage announcements" ON announcements FOR UPDATE USING (
  author_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND role IN ('officer', 'admin', 'super_admin')
  )
);

-- =====================================================
-- Resource Management Policies
-- =====================================================

-- Resource Categories: Public read access
CREATE POLICY "Public can view resource categories" ON resource_categories FOR SELECT USING (true);
CREATE POLICY "Admins can manage resource categories" ON resource_categories FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Resources: Public and chapter-based access
CREATE POLICY "Users can view resources" ON resources FOR SELECT USING (
  is_public = true OR
  uploader_id = auth.uid() OR
  chapter_id IN (
    SELECT chapter_id FROM chapter_memberships
    WHERE user_id = auth.uid() AND is_active = true
  )
);
CREATE POLICY "Users can upload resources" ON resources FOR INSERT WITH CHECK (
  uploader_id = auth.uid() AND (
    chapter_id IS NULL OR
    EXISTS (
      SELECT 1 FROM chapter_memberships cm
      JOIN profiles p ON cm.user_id = p.id
      WHERE cm.chapter_id = resources.chapter_id AND cm.user_id = auth.uid()
      AND cm.is_active = true AND p.role IN ('officer', 'admin', 'super_admin')
    )
  )
);
CREATE POLICY "Uploaders can manage resources" ON resources FOR UPDATE USING (
  uploader_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
);

-- Resource Downloads: Users can manage their own downloads
CREATE POLICY "Users can manage downloads" ON resource_downloads FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users can create downloads" ON resource_downloads FOR INSERT WITH CHECK (
  user_id = auth.uid() AND
  resource_id IN (
    SELECT id FROM resources WHERE
    is_public = true OR
    uploader_id = auth.uid() OR
    chapter_id IN (
      SELECT chapter_id FROM chapter_memberships
      WHERE user_id = auth.uid() AND is_active = true
    )
  )
);

-- Resource Ratings: Users can rate accessible resources
CREATE POLICY "Users can manage ratings" ON resource_ratings FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users can create ratings" ON resource_ratings FOR INSERT WITH CHECK (
  user_id = auth.uid() AND
  resource_id IN (
    SELECT id FROM resources WHERE
    is_public = true OR
    uploader_id = auth.uid() OR
    chapter_id IN (
      SELECT chapter_id FROM chapter_memberships
      WHERE user_id = auth.uid() AND is_active = true
    )
  )
);

-- =====================================================
-- Gamification Policies
-- =====================================================

-- Achievements: Public read access
CREATE POLICY "Public can view achievements" ON achievements FOR SELECT USING (is_active = true);
CREATE POLICY "Admins can manage achievements" ON achievements FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- User Achievements: Personal access
CREATE POLICY "Users can manage own achievements" ON user_achievements FOR ALL USING (user_id = auth.uid());

-- Points: Users can view their own points, admins can view all
CREATE POLICY "Users can view own points" ON points FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Admins can view all points" ON points FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage points" ON points FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Leaderboards: Public read access
CREATE POLICY "Public can view leaderboards" ON leaderboards FOR SELECT USING (true);
CREATE POLICY "Admins can manage leaderboards" ON leaderboards FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);