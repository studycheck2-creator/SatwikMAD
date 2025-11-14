import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Supabase configuration - HARDCODED for reliability
const supabaseUrl = 'https://forddbtpuljnlagvogzu.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvcmRkYnRwdWxqbmxhZ3ZvZ3p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI5MTE1NTMsImV4cCI6MjA3ODQ4NzU1M30.VCO7QjH8nleEKN357nQfbToUALThkXzqn2EXZEHLmcs';

// Create Supabase client with AsyncStorage for session persistence
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// Database types for the complete Supabase backend
export interface Database {
  public: {
    Tables: {
      // User Management
      profiles: {
        Row: {
          id: string;
          username: string | null;
          full_name: string | null;
          avatar_url: string | null;
          bio: string | null;
          website: string | null;
          location: string | null;
          phone: string | null;
          grade: string | null;
          role: 'member' | 'officer' | 'admin' | 'super_admin';
          is_active: boolean;
          email_verified: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['profiles']['Row'], 'id' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['profiles']['Insert']>;
      };
      user_settings: {
        Row: {
          id: string;
          push_notifications: boolean;
          email_notifications: boolean;
          theme: 'light' | 'dark' | 'auto';
          language: string;
          timezone: string;
          privacy_profile_public: boolean;
          privacy_show_email: boolean;
          privacy_show_phone: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['user_settings']['Row'], 'id' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['user_settings']['Insert']>;
      };
      chapters: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          school_name: string | null;
          location: string | null;
          website: string | null;
          logo_url: string | null;
          is_active: boolean;
          created_by: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['chapters']['Row'], 'id' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['chapters']['Insert']>;
      };
      chapter_memberships: {
        Row: {
          id: string;
          user_id: string;
          chapter_id: string;
          role: 'member' | 'officer' | 'advisor';
          joined_at: string;
          left_at: string | null;
          is_active: boolean;
        };
        Insert: Omit<Database['public']['Tables']['chapter_memberships']['Row'], 'id' | 'joined_at'>;
        Update: Partial<Database['public']['Tables']['chapter_memberships']['Insert']>;
      };

      // Content & Media
      posts: {
        Row: {
          id: string;
          author_id: string;
          chapter_id: string | null;
          title: string | null;
          content: string;
          type: 'post' | 'announcement' | 'achievement' | 'update';
          visibility: 'public' | 'chapter' | 'private';
          media_urls: string[] | null;
          tags: string[] | null;
          like_count: number;
          comment_count: number;
          share_count: number;
          is_pinned: boolean;
          is_draft: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['posts']['Row'], 'id' | 'like_count' | 'comment_count' | 'share_count' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['posts']['Insert']>;
      };
      media: {
        Row: {
          id: string;
          uploader_id: string;
          post_id: string | null;
          event_id: string | null;
          resource_id: string | null;
          filename: string;
          original_name: string;
          file_type: string;
          file_size: number;
          file_path: string;
          thumbnail_url: string | null;
          metadata: any | null;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['media']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['media']['Insert']>;
      };
      comments: {
        Row: {
          id: string;
          author_id: string;
          post_id: string;
          parent_id: string | null;
          content: string;
          like_count: number;
          reply_count: number;
          is_edited: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['comments']['Row'], 'id' | 'like_count' | 'reply_count' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['comments']['Insert']>;
      };
      likes: {
        Row: {
          id: string;
          user_id: string;
          target_type: 'post' | 'comment' | 'event' | 'resource';
          target_id: string;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['likes']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['likes']['Insert']>;
      };

      // Social Interactions
      follows: {
        Row: {
          id: string;
          follower_id: string;
          following_id: string;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['follows']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['follows']['Insert']>;
      };
      shares: {
        Row: {
          id: string;
          user_id: string;
          post_id: string;
          caption: string | null;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['shares']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['shares']['Insert']>;
      };
      mentions: {
        Row: {
          id: string;
          mentioned_user_id: string;
          mentioner_id: string;
          target_type: 'post' | 'comment';
          target_id: string;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['mentions']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['mentions']['Insert']>;
      };
      bookmarks: {
        Row: {
          id: string;
          user_id: string;
          target_type: 'post' | 'event' | 'resource';
          target_id: string;
          folder: string;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['bookmarks']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['bookmarks']['Insert']>;
      };

      // Events
      events: {
        Row: {
          id: string;
          title: string;
          description: string | null;
          chapter_id: string | null;
          organizer_id: string;
          category: 'meeting' | 'competition' | 'workshop' | 'social' | 'fundraiser' | 'community_service' | 'general';
          location: string | null;
          virtual_meeting_url: string | null;
          start_time: string;
          end_time: string;
          max_attendees: number | null;
          registration_deadline: string | null;
          image_url: string | null;
          is_public: boolean;
          requires_registration: boolean;
          status: 'upcoming' | 'ongoing' | 'completed' | 'cancelled';
          attendee_count: number;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['events']['Row'], 'id' | 'attendee_count' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['events']['Insert']>;
      };
      event_registrations: {
        Row: {
          id: string;
          event_id: string;
          user_id: string;
          registered_at: string;
          attended: boolean;
          notes: string | null;
        };
        Insert: Omit<Database['public']['Tables']['event_registrations']['Row'], 'id' | 'registered_at'>;
        Update: Partial<Database['public']['Tables']['event_registrations']['Insert']>;
      };
      event_feedback: {
        Row: {
          id: string;
          event_id: string;
          user_id: string;
          rating: number | null;
          feedback: string | null;
          submitted_at: string;
        };
        Insert: Omit<Database['public']['Tables']['event_feedback']['Row'], 'id' | 'submitted_at'>;
        Update: Partial<Database['public']['Tables']['event_feedback']['Insert']>;
      };

      // Communication
      notifications: {
        Row: {
          id: string;
          user_id: string;
          type: 'like' | 'comment' | 'follow' | 'mention' | 'event_reminder' | 'announcement' | 'achievement' | 'system';
          title: string;
          message: string;
          data: any | null;
          is_read: boolean;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['notifications']['Row'], 'id' | 'is_read' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['notifications']['Insert']>;
      };
      message_threads: {
        Row: {
          id: string;
          participant1_id: string;
          participant2_id: string;
          last_message_at: string;
          last_message_preview: string | null;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['message_threads']['Row'], 'id' | 'last_message_at' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['message_threads']['Insert']>;
      };
      messages: {
        Row: {
          id: string;
          thread_id: string;
          sender_id: string;
          content: string;
          media_url: string | null;
          is_read: boolean;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['messages']['Row'], 'id' | 'is_read' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['messages']['Insert']>;
      };
      announcements: {
        Row: {
          id: string;
          author_id: string;
          chapter_id: string | null;
          title: string;
          content: string;
          priority: 'low' | 'normal' | 'high' | 'urgent';
          is_published: boolean;
          publish_at: string;
          expires_at: string | null;
          view_count: number;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['announcements']['Row'], 'id' | 'view_count' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['announcements']['Insert']>;
      };

      // Resources
      resource_categories: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          parent_id: string | null;
          icon: string | null;
          sort_order: number;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['resource_categories']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['resource_categories']['Insert']>;
      };
      resources: {
        Row: {
          id: string;
          title: string;
          description: string | null;
          category_id: string | null;
          chapter_id: string | null;
          uploader_id: string;
          file_url: string;
          file_name: string;
          file_type: string;
          file_size: number;
          thumbnail_url: string | null;
          download_count: number;
          rating_average: number;
          rating_count: number;
          is_public: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['resources']['Row'], 'id' | 'download_count' | 'rating_average' | 'rating_count' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['resources']['Insert']>;
      };
      resource_downloads: {
        Row: {
          id: string;
          resource_id: string;
          user_id: string;
          downloaded_at: string;
        };
        Insert: Omit<Database['public']['Tables']['resource_downloads']['Row'], 'id' | 'downloaded_at'>;
        Update: Partial<Database['public']['Tables']['resource_downloads']['Insert']>;
      };
      resource_ratings: {
        Row: {
          id: string;
          resource_id: string;
          user_id: string;
          rating: number;
          review: string | null;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['resource_ratings']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['resource_ratings']['Insert']>;
      };

      // Gamification
      achievements: {
        Row: {
          id: string;
          name: string;
          description: string;
          icon: string | null;
          points: number;
          type: 'automatic' | 'manual' | 'milestone';
          criteria: any | null;
          is_active: boolean;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['achievements']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['achievements']['Insert']>;
      };
      user_achievements: {
        Row: {
          id: string;
          user_id: string;
          achievement_id: string;
          earned_at: string;
        };
        Insert: Omit<Database['public']['Tables']['user_achievements']['Row'], 'id' | 'earned_at'>;
        Update: Partial<Database['public']['Tables']['user_achievements']['Insert']>;
      };
      points: {
        Row: {
          id: string;
          user_id: string;
          amount: number;
          reason: string;
          source_type: 'post' | 'comment' | 'event_attendance' | 'achievement' | 'manual' | null;
          source_id: string | null;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['points']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['points']['Insert']>;
      };
      leaderboards: {
        Row: {
          id: string;
          type: 'points' | 'posts' | 'likes' | 'event_attendance';
          period: 'daily' | 'weekly' | 'monthly' | 'all_time';
          user_id: string;
          score: number;
          rank_position: number | null;
          calculated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['leaderboards']['Row'], 'id' | 'calculated_at'>;
        Update: Partial<Database['public']['Tables']['leaderboards']['Insert']>;
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      [_ in never]: never;
    };
  };
}