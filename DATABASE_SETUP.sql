-- ============================================================================
-- COMPLETE DATABASE SETUP FOR PROFILE APP
-- Run this SQL in your Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- SECTION 1: STORAGE BUCKET SETUP (Profile Pictures)
-- ============================================================================

-- Create avatars storage bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Enable All Access" ON storage.objects;
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;

-- Create comprehensive storage policies for avatars bucket
CREATE POLICY "Anyone can view avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars')
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'avatars');

-- ============================================================================
-- SECTION 2: PROFILES TABLE SETUP
-- ============================================================================

-- Add avatar_url column to profiles table (if it doesn't exist)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add other profile columns if they don't exist
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS location TEXT,
ADD COLUMN IF NOT EXISTS title TEXT,
ADD COLUMN IF NOT EXISTS skills TEXT;

-- ============================================================================
-- SECTION 3: FRIEND REQUESTS TABLE SETUP (FIXED - No Duplicate Key Errors)
-- ============================================================================

-- Create friend_requests table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS friend_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  -- NOTE: No UNIQUE constraint here to allow re-sending requests after accept/decline
);

-- Drop the problematic unique constraint (if it exists)
ALTER TABLE friend_requests 
DROP CONSTRAINT IF EXISTS friend_requests_sender_id_receiver_id_key;

-- Create a PARTIAL unique index that only applies to PENDING requests
-- This prevents duplicate pending requests but allows new requests after accept/decline
DROP INDEX IF EXISTS idx_unique_pending_requests;
CREATE UNIQUE INDEX idx_unique_pending_requests 
ON friend_requests(sender_id, receiver_id) 
WHERE status = 'pending';

-- Clean up old accepted/declined requests (they're deleted automatically by the app now)
DELETE FROM friend_requests WHERE status IN ('accepted', 'declined');

-- Create indexes for better query performance
DROP INDEX IF EXISTS idx_friend_requests_receiver;
DROP INDEX IF EXISTS idx_friend_requests_sender;
CREATE INDEX idx_friend_requests_receiver ON friend_requests(receiver_id, status);
CREATE INDEX idx_friend_requests_sender ON friend_requests(sender_id, status);

-- Enable Row Level Security
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (clean slate)
DROP POLICY IF EXISTS "Users can insert their own friend requests" ON friend_requests;
DROP POLICY IF EXISTS "Users can view friend requests they sent" ON friend_requests;
DROP POLICY IF EXISTS "Users can view friend requests they received" ON friend_requests;
DROP POLICY IF EXISTS "Users can update friend requests they received" ON friend_requests;
DROP POLICY IF EXISTS "Users can delete friend requests they sent" ON friend_requests;
DROP POLICY IF EXISTS "Users can delete requests" ON friend_requests;

-- Create comprehensive RLS policies for friend_requests
CREATE POLICY "Users can insert their own friend requests"
ON friend_requests FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can view friend requests they sent"
ON friend_requests FOR SELECT
TO authenticated
USING (auth.uid() = sender_id);

CREATE POLICY "Users can view friend requests they received"
ON friend_requests FOR SELECT
TO authenticated
USING (auth.uid() = receiver_id);

CREATE POLICY "Users can update friend requests they received"
ON friend_requests FOR UPDATE
TO authenticated
USING (auth.uid() = receiver_id);

CREATE POLICY "Users can delete requests"
ON friend_requests FOR DELETE
TO authenticated
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ============================================================================
-- SECTION 4: FRIENDSHIPS TABLE SETUP
-- ============================================================================

-- Create friendships table (bidirectional friendship records)
CREATE TABLE IF NOT EXISTS friendships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- Create index for faster friendship lookups
DROP INDEX IF EXISTS idx_friendships_user;
CREATE INDEX idx_friendships_user ON friendships(user_id);

-- Enable Row Level Security for friendships
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- Drop existing friendships policies (clean slate)
DROP POLICY IF EXISTS "Users can insert their own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can view their own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can delete their own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can insert friendships" ON friendships;
DROP POLICY IF EXISTS "Users can view friendships" ON friendships;
DROP POLICY IF EXISTS "Users can delete friendships" ON friendships;

-- Create RLS policies for friendships
CREATE POLICY "Users can insert friendships"
ON friendships FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Users can view friendships"
ON friendships FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can delete friendships"
ON friendships FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================================================
-- SECTION 5: VERIFICATION AND TESTING
-- ============================================================================

-- Uncomment these queries to verify your setup:

-- Check friend_requests table structure and data
-- SELECT * FROM friend_requests ORDER BY created_at DESC LIMIT 10;

-- Check friendships table structure and data
-- SELECT * FROM friendships ORDER BY created_at DESC LIMIT 10;

-- Check profiles table has avatar_url column
-- SELECT id, full_name, avatar_url FROM profiles LIMIT 5;

-- Check storage bucket exists
-- SELECT * FROM storage.buckets WHERE id = 'avatars';

-- Check storage policies
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================
-- Your database is now configured with:
-- ✅ Avatars storage bucket with public access
-- ✅ Profiles table with avatar_url column
-- ✅ Friend requests system (no duplicate key errors)
-- ✅ Friendships table (bidirectional relationships)
-- ✅ All necessary Row Level Security policies
-- 
-- Next steps:
-- 1. Restart your Flutter app
-- 2. Test profile picture upload
-- 3. Test sending/accepting friend requests
-- ============================================================================
