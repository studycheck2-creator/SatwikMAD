-- =====================================================
-- Storage Buckets and Policies
-- =====================================================

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('profile-images', 'profile-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('post-media', 'post-media', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/quicktime', 'application/pdf']),
  ('event-media', 'event-media', true, 20971520, ARRAY['image/jpeg', 'image/png', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('resources', 'resources', true, 104857600, ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'text/plain']),
  ('temp-uploads', 'temp-uploads', false, 104857600, NULL) -- All types allowed for temp
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- Storage Access Policies
-- =====================================================

-- Profile Images Bucket Policies
CREATE POLICY "Public can view profile images" ON storage.objects FOR SELECT USING (
  bucket_id = 'profile-images'
);

CREATE POLICY "Users can upload own profile image" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'profile-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update own profile image" ON storage.objects FOR UPDATE USING (
  bucket_id = 'profile-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own profile image" ON storage.objects FOR DELETE USING (
  bucket_id = 'profile-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Post Media Bucket Policies
CREATE POLICY "Public can view post media" ON storage.objects FOR SELECT USING (
  bucket_id = 'post-media' AND
  (
    -- Public post media
    EXISTS (
      SELECT 1 FROM posts WHERE id = (storage.foldername(name))[1] AND visibility = 'public'
    ) OR
    -- User's own media
    EXISTS (
      SELECT 1 FROM posts WHERE id = (storage.foldername(name))[1] AND author_id = auth.uid()
    ) OR
    -- Chapter member media
    EXISTS (
      SELECT 1 FROM posts WHERE id = (storage.foldername(name))[1]
      AND visibility = 'chapter' AND chapter_id IN (
        SELECT chapter_id FROM chapter_memberships
        WHERE user_id = auth.uid() AND is_active = true
      )
    )
  )
);

CREATE POLICY "Post authors can upload media" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'post-media' AND
  EXISTS (
    SELECT 1 FROM posts WHERE id = (storage.foldername(name))[1] AND author_id = auth.uid()
  )
);

CREATE POLICY "Post authors can manage media" ON storage.objects FOR UPDATE USING (
  bucket_id = 'post-media' AND
  EXISTS (
    SELECT 1 FROM posts WHERE id = (storage.foldername(name))[1] AND author_id = auth.uid()
  )
);

-- Event Media Bucket Policies
CREATE POLICY "Public can view event media" ON storage.objects FOR SELECT USING (
  bucket_id = 'event-media'
);

CREATE POLICY "Event organizers can upload media" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'event-media' AND
  EXISTS (
    SELECT 1 FROM events WHERE id = (storage.foldername(name))[1] AND organizer_id = auth.uid()
  )
);

CREATE POLICY "Officers can upload event media" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'event-media' AND
  EXISTS (
    SELECT 1 FROM events WHERE id = (storage.foldername(name))[1]
    AND chapter_id IN (
      SELECT chapter_id FROM chapter_memberships cm
      JOIN profiles p ON cm.user_id = p.id
      WHERE cm.chapter_id = events.chapter_id AND cm.user_id = auth.uid()
      AND cm.is_active = true AND p.role IN ('officer', 'admin', 'super_admin')
    )
  )
);

CREATE POLICY "Event organizers can manage media" ON storage.objects FOR UPDATE USING (
  bucket_id = 'event-media' AND
  EXISTS (
    SELECT 1 FROM events WHERE id = (storage.foldername(name))[1] AND organizer_id = auth.uid()
  )
);

-- Resources Bucket Policies
CREATE POLICY "Public can view resource files" ON storage.objects FOR SELECT USING (
  bucket_id = 'resources' AND
  (
    -- Public resources
    EXISTS (
      SELECT 1 FROM resources WHERE file_url = storage.foldername(name) || '/' || storage.filename(name) AND is_public = true
    ) OR
    -- User's own resources
    EXISTS (
      SELECT 1 FROM resources WHERE file_url = storage.foldername(name) || '/' || storage.filename(name) AND uploader_id = auth.uid()
    ) OR
    -- Chapter member resources
    EXISTS (
      SELECT 1 FROM resources WHERE file_url = storage.foldername(name) || '/' || storage.filename(name)
      AND chapter_id IN (
        SELECT chapter_id FROM chapter_memberships
        WHERE user_id = auth.uid() AND is_active = true
      )
    )
  )
);

CREATE POLICY "Officers can upload resources" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'resources' AND
  (
    -- General uploads (no specific category)
    storage.foldername(name) = 'general' OR
    -- Chapter-specific uploads
    EXISTS (
      SELECT 1 FROM chapters WHERE id::text = storage.foldername(name)
    )
  ) AND
  (
    uploader_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM chapter_memberships cm
      JOIN profiles p ON cm.user_id = p.id
      WHERE cm.chapter_id::text = storage.foldername(name) AND cm.user_id = auth.uid()
      AND cm.is_active = true AND p.role IN ('officer', 'admin', 'super_admin')
    )
  )
);

-- Temp Uploads Bucket Policies (Private)
CREATE POLICY "Users can manage temp uploads" ON storage.objects FOR ALL USING (
  bucket_id = 'temp-uploads' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- =====================================================
-- Storage Helper Functions
-- =====================================================

-- Clean up temp uploads older than 24 hours
CREATE OR REPLACE FUNCTION cleanup_temp_uploads()
RETURNS void AS $$
BEGIN
  DELETE FROM storage.objects
  WHERE bucket_id = 'temp-uploads'
  AND created_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Function to get public URL for a file
CREATE OR REPLACE FUNCTION get_public_url(bucket_name TEXT, file_path TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN (
    SELECT '/storage/v1/object/public/' || bucket_name || '/' || file_path
  );
END;
$$ LANGUAGE plpgsql;

-- Function to check if user can access a resource file
CREATE OR REPLACE FUNCTION can_access_resource(file_path TEXT, user_id_param UUID)
RETURNS BOOLEAN AS $$
DECLARE
  resource_record RECORD;
BEGIN
  -- Find the resource associated with this file path
  SELECT * INTO resource_record
  FROM resources
  WHERE file_url = file_path;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Check access conditions
  RETURN (
    resource_record.is_public = true OR
    resource_record.uploader_id = user_id_param OR
    (
      resource_record.chapter_id IN (
        SELECT chapter_id FROM chapter_memberships
        WHERE user_id = user_id_param AND is_active = true
      )
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate a unique filename for uploads
CREATE OR REPLACE FUNCTION generate_unique_filename(original_name TEXT, user_id_param UUID)
RETURNS TEXT AS $$
DECLARE
  file_extension TEXT;
  base_name TEXT;
  unique_name TEXT;
  timestamp TEXT;
BEGIN
  -- Extract file extension
  file_extension := SUBSTRING(original_name FROM '\.([^.]+)$');

  -- Remove extension from base name
  base_name := SUBSTRING(original_name FROM '^(.+)\.');

  -- Generate timestamp
  timestamp := EXTRACT(EPOCH FROM NOW())::TEXT;

  -- Create unique filename
  unique_name := user_id_param::TEXT || '/' || timestamp || '_' ||
                 REGEXP_REPLACE(base_name, '[^a-zA-Z0-9_-]', '', 'g') ||
                 '.' || file_extension;

  RETURN unique_name;
END;
$$ LANGUAGE plpgsql;