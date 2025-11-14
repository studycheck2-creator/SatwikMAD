import { supabase, Database } from './supabase';
import { PostgrestError } from '@supabase/supabase-js';

// =====================================================
// User Profile Helpers
// =====================================================

export const profileHelpers = {
  // Get current user's profile
  async getCurrentProfile() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    const { data, error } = await supabase
      .from('profiles')
      .select(`
        *,
        user_settings(*),
        chapter_memberships(
          id,
          chapters(*),
          role
        )
      `)
      .eq('id', user.id)
      .single();

    if (error) throw error;
    return data;
  },

  // Update user profile
  async updateProfile(updates: Partial<Database['public']['Tables']['profiles']['Update']>) {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.id)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  // Update user settings
  async updateSettings(updates: Partial<Database['public']['Tables']['user_settings']['Update']>) {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    const { data, error } = await supabase
      .from('user_settings')
      .update(updates)
      .eq('id', user.id)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  // Search for other users
  async searchUsers(query: string, limit = 20) {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, username, full_name, avatar_url, bio, role')
      .or(`username.ilike.%${query}%,full_name.ilike.%${query}%`)
      .limit(limit);

    if (error) throw error;
    return data;
  }
};

// =====================================================
// Posts and Content Helpers
// =====================================================

export const postHelpers = {
  // Get posts for user's feed
  async getFeed(limit = 20, offset = 0) {
    const { data, error } = await supabase
      .from('posts')
      .select(`
        *,
        author:profiles(username, full_name, avatar_url),
        chapter:chapters(name),
        media(*),
        comments(count),
        likes(count)
      `)
      .in('visibility', ['public'])
      .is('is_draft', false)
      .order('is_pinned', { ascending: false })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw error;
    return data;
  },

  // Get chapter posts
  async getChapterPosts(chapterId: string, limit = 20, offset = 0) {
    const { data, error } = await supabase
      .from('posts')
      .select(`
        *,
        author:profiles(username, full_name, avatar_url),
        chapter:chapters(name),
        media(*),
        comments(count),
        likes(count)
      `)
      .eq('chapter_id', chapterId)
      .in('visibility', ['public', 'chapter'])
      .is('is_draft', false)
      .order('is_pinned', { ascending: false })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw error;
    return data;
  },

  // Get user's posts
  async getUserPosts(userId: string, limit = 20, offset = 0) {
    const { data, error } = await supabase
      .from('posts')
      .select(`
        *,
        author:profiles(username, full_name, avatar_url),
        chapter:chapters(name),
        media(*),
        comments(count),
        likes(count)
      `)
      .eq('author_id', userId)
      .is('is_draft', false)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw error;
    return data;
  },

  // Create a new post
  async createPost(post: Database['public']['Tables']['posts']['Insert']) {
    const { data, error } = await supabase
      .from('posts')
      .insert(post)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  // Like or unlike a post
  async toggleLike(postId: string) {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    // Check if already liked
    const { data: existingLike } = await supabase
      .from('likes')
      .select()
      .eq('user_id', user.id)
      .eq('target_type', 'post')
      .eq('target_id', postId)
      .single();

    if (existingLike) {
      // Unlike
      const { error } = await supabase
        .from('likes')
        .delete()
        .eq('id', existingLike.id);

      if (error) throw error;
      return false;
    } else {
      // Like
      const { error } = await supabase
        .from('likes')
        .insert({
          user_id: user.id,
          target_type: 'post',
          target_id: postId
        });

      if (error) throw error;
      return true;
    }
  }
};

// =====================================================
// Event Helpers
// =====================================================

export const eventHelpers = {
  // Get upcoming events
  async getUpcomingEvents(limit = 20) {
    const { data, error } = await supabase
      .from('events')
      .select(`
        *,
        organizer:profiles(username, full_name, avatar_url),
        chapter:chapters(name),
        event_registrations(count)
      `)
      .in('status', ['upcoming', 'ongoing'])
      .order('start_time', { ascending: true })
      .limit(limit);

    if (error) throw error;
    return data;
  },

  // Get event details
  async getEventDetails(eventId: string) {
    const { data, error } = await supabase
      .from('events')
      .select(`
        *,
        organizer:profiles(username, full_name, avatar_url),
        chapter:chapters(name),
        event_registrations(
          id,
          user_id,
          registered_at,
          attended,
          profiles(username, full_name, avatar_url)
        ),
        event_feedback(rating, feedback, submitted_at, profiles(username))
      `)
      .eq('id', eventId)
      .single();

    if (error) throw error;
    return data;
  },

  // Register for an event
  async registerForEvent(eventId: string, notes?: string) {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    const { data, error } = await supabase
      .from('event_registrations')
      .insert({
        event_id: eventId,
        user_id: user.id,
        notes
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  // Submit event feedback
  async submitEventFeedback(eventId: string, rating: number, feedback?: string) {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    const { data, error } = await supabase
      .from('event_feedback')
      .upsert({
        event_id: eventId,
        user_id: user.id,
        rating,
        feedback,
        submitted_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }
};

// =====================================================
// Resource Helpers
// =====================================================

export const resourceHelpers = {
  // Get resources with categories
  async getResources(categoryId?: string, limit = 20, offset = 0) {
    let query = supabase
      .from('resources')
      .select(`
        *,
        uploader:profiles(username, full_name, avatar_url),
        category:resource_categories(name, icon),
        chapter:chapters(name),
        resource_ratings(average_rating)
      `)
      .eq('is_public', true)
      .order('created_at', { ascending: false });

    if (categoryId) {
      query = query.eq('category_id', categoryId);
    }

    const { data, error } = await query.range(offset, offset + limit - 1);
    if (error) throw error;
    return data;
  },

  // Get resource categories
  async getResourceCategories() {
    const { data, error } = await supabase
      .from('resource_categories')
      .select(`
        *,
        resources(count)
      `)
      .order('sort_order');

    if (error) throw error;
    return data;
  },

  // Download a resource (tracks download)
  async downloadResource(resourceId: string) {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    // Get resource details
    const { data: resource, error: fetchError } = await supabase
      .from('resources')
      .select('file_url, file_name')
      .eq('id', resourceId)
      .single();

    if (fetchError) throw fetchError;

    // Track download
    const { error: trackError } = await supabase
      .from('resource_downloads')
      .insert({
        resource_id: resourceId,
        user_id: user.id
      });

    if (trackError) throw trackError;

    // Get public URL
    const { data } = supabase.storage
      .from('resources')
      .getPublicUrl(resource.file_url);

    return data.publicUrl;
  },

  // Rate a resource
  async rateResource(resourceId: string, rating: number, review?: string) {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    const { data, error } = await supabase
      .from('resource_ratings')
      .upsert({
        resource_id: resourceId,
        user_id: user.id,
        rating,
        review
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }
};

// =====================================================
// Notification Helpers
// =====================================================

export const notificationHelpers = {
  // Get user notifications
  async getNotifications(limit = 20, offset = 0) {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('is_read', false)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw error;
    return data;
  },

  // Mark notification as read
  async markAsRead(notificationId: string) {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', notificationId);

    if (error) throw error;
  },

  // Mark all notifications as read
  async markAllAsRead() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('No authenticated user');

    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', user.id)
      .eq('is_read', false);

    if (error) throw error;
  },

  // Get unread count
  async getUnreadCount() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return 0;

    const { count, error } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('is_read', false);

    if (error) throw error;
    return count || 0;
  }
};

// =====================================================
// Storage/File Upload Helpers
// =====================================================

export const storageHelpers = {
  // Upload profile picture
  async uploadProfilePicture(file: File, userId: string) {
    const fileExt = file.name.split('.').pop();
    const fileName = `${userId}/avatar.${fileExt}`;

    const { error } = await supabase.storage
      .from('profile-images')
      .upload(fileName, file, {
        upsert: true,
        contentType: file.type
      });

    if (error) throw error;

    // Get public URL
    const { data } = supabase.storage
      .from('profile-images')
      .getPublicUrl(fileName);

    return data.publicUrl;
  },

  // Upload post media
  async uploadPostMedia(file: File, postId: string) {
    const timestamp = Date.now();
    const fileExt = file.name.split('.').pop();
    const fileName = `${postId}/${timestamp}_${file.name}`;

    const { error } = await supabase.storage
      .from('post-media')
      .upload(fileName, file, {
        upsert: true,
        contentType: file.type
      });

    if (error) throw error;

    // Get public URL
    const { data } = supabase.storage
      .from('post-media')
      .getPublicUrl(fileName);

    return data.publicUrl;
  },

  // Upload resource file
  async uploadResourceFile(file: File, category: string) {
    const timestamp = Date.now();
    const fileName = `${category}/${timestamp}_${file.name}`;

    const { error } = await supabase.storage
      .from('resources')
      .upload(fileName, file, {
        upsert: true,
        contentType: file.type
      });

    if (error) throw error;

    // Get public URL
    const { data } = supabase.storage
      .from('resources')
      .getPublicUrl(fileName);

    return { publicUrl: data.publicUrl, filePath: fileName };
  }
};

// =====================================================
// Real-time Subscription Helpers
// =====================================================

export const realtimeHelpers = {
  // Subscribe to new posts
  subscribeToPosts(callback: (payload: any) => void) {
    return supabase
      .channel('posts')
      .on('postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'posts'
        },
        callback
      )
      .subscribe();
  },

  // Subscribe to notifications
  subscribeToNotifications(userId: string, callback: (payload: any) => void) {
    return supabase
      .channel('notifications')
      .on('postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${userId}`
        },
        callback
      )
      .subscribe();
  },

  // Subscribe to new likes on user's posts
  subscribeToLikes(userId: string, callback: (payload: any) => void) {
    return supabase
      .channel('likes')
      .on('postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'likes',
          filter: `user_id=eq.${userId}`
        },
        callback
      )
      .subscribe();
  }
};

// =====================================================
// Error Handling Helper
// =====================================================

export const handleDatabaseError = (error: PostgrestError): string => {
  console.error('Database error:', error);

  // Common error messages
  switch (error.code) {
    case '23505':
      return 'This record already exists.';
    case '23503':
      return 'Referenced record not found.';
    case '23514':
      return 'Invalid data provided.';
    case '42501':
      return 'You do not have permission to perform this action.';
    case 'PGRST116':
      return 'Record not found.';
    default:
      return error.message || 'An unexpected error occurred.';
  }
};