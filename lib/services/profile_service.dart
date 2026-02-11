import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get the current user's profile
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single(); // .single() is important because we expect only 1 row!
          
      return data;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  // Get any user's profile by ID
  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
          
      return data;
    } catch (e) {
      print('Error fetching profile by ID: $e');
      return null;
    }
  }

  // Update profile with ALL fields
  Future<void> updateProfile({
    String? fullName, 
    String? bio,
    String? phone,
    String? location,
    String? title,
    String? skills,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Build update map with only non-null values
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (fullName != null) updates['full_name'] = fullName;
      if (bio != null) updates['bio'] = bio;
      if (phone != null) updates['phone'] = phone;
      if (location != null) updates['location'] = location;
      if (title != null) updates['title'] = title;
      if (skills != null) updates['skills'] = skills;
      
      await _supabase.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Search for other users
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      
      if (query.isEmpty) {
        // Return all users except current user
        final data = await _supabase
            .from('profiles')
            .select()
            .neq('id', currentUserId);
        return List<Map<String, dynamic>>.from(data);
      }
      
      // Search for names or titles matching the query, excluding yourself
      final data = await _supabase
          .from('profiles')
          .select()
          .neq('id', currentUserId)
          .or('full_name.ilike.%$query%,title.ilike.%$query%');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Send friend request
  Future<void> sendFriendRequest(String receiverId) async {
    try {
      final senderId = _supabase.auth.currentUser!.id;
      
      // Check if already friends
      final friendship = await _supabase
          .from('friendships')
          .select()
          .eq('user_id', senderId)
          .eq('friend_id', receiverId)
          .maybeSingle();
      
      if (friendship != null) {
        throw Exception('You are already friends with this user');
      }
      
      // Check if request already exists
      final existing = await _supabase
          .from('friend_requests')
          .select()
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId)
          .eq('status', 'pending')
          .maybeSingle();
      
      if (existing != null) {
        throw Exception('Friend request already sent');
      }
      
      await _supabase.from('friend_requests').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
      });
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  // Get pending friend requests for current user
  Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final data = await _supabase
          .from('friend_requests')
          .select('*, sender:profiles!friend_requests_sender_id_fkey(id, full_name, title)')
          .eq('receiver_id', userId)
          .eq('status', 'pending');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching friend requests: $e');
      return [];
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // 1. Update the request status to 'accepted'
      await _supabase
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      // 2. Create the friendship (Link both ways) - removed status field
      await _supabase.from('friendships').insert([
        {'user_id': currentUserId, 'friend_id': senderId},
        {'user_id': senderId, 'friend_id': currentUserId},
      ]);
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }

  // Decline friend request
  Future<void> declineFriendRequest(String requestId) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'declined'})
          .eq('id', requestId);
    } catch (e) {
      print('Error declining friend request: $e');
      rethrow;
    }
  }

  // Get friend count
  Future<int> getFriendCount() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('friendships')
          .select()
          .eq('user_id', userId)
          .count(CountOption.exact);
          
      return response.count;
    } catch (e) {
      print('Error getting friend count: $e');
      return 0;
    }
  }

  // Get friends list
  Future<List<Map<String, dynamic>>> getFriends() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final data = await _supabase
          .from('friendships')
          .select('friend:profiles!friendships_friend_id_fkey(id, full_name, title, bio)')
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching friends: $e');
      return [];
    }
  }

  // Get pending friend requests count (for notification badge)
  Future<int> getPendingRequestsCount() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('friend_requests')
          .select()
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting pending requests count: $e');
      return 0;
    }
  }

  // Check relationship status with another user
  // Returns: 'friend', 'pending_sent', 'pending_received', 'none'
  Future<String> checkFriendStatus(String otherUserId) async {
    try {
      final myId = _supabase.auth.currentUser!.id;

      // Check if already friends
      final friendship = await _supabase
          .from('friendships')
          .select()
          .eq('user_id', myId)
          .eq('friend_id', otherUserId)
          .maybeSingle();

      if (friendship != null) return 'friend';

      // Check for pending friend request (sent by me)
      final sentRequest = await _supabase
          .from('friend_requests')
          .select()
          .eq('sender_id', myId)
          .eq('receiver_id', otherUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (sentRequest != null) return 'pending_sent';

      // Check for pending friend request (received from them)
      final receivedRequest = await _supabase
          .from('friend_requests')
          .select()
          .eq('sender_id', otherUserId)
          .eq('receiver_id', myId)
          .eq('status', 'pending')
          .maybeSingle();

      if (receivedRequest != null) return 'pending_received';

      return 'none';
    } catch (e) {
      print('Error checking friend status: $e');
      return 'none';
    }
  }

  // Unfriend a user (remove friendship)
  Future<void> unfriend(String friendId) async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      
      // Delete both friendship records (bidirectional)
      await _supabase
          .from('friendships')
          .delete()
          .eq('user_id', myId)
          .eq('friend_id', friendId);
      
      await _supabase
          .from('friendships')
          .delete()
          .eq('user_id', friendId)
          .eq('friend_id', myId);
    } catch (e) {
      print('Error unfriending: $e');
      rethrow;
    }
  }

  // Cancel a friend request that I sent
  Future<void> cancelFriendRequest(String receiverId) async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      
      await _supabase
          .from('friend_requests')
          .delete()
          .eq('sender_id', myId)
          .eq('receiver_id', receiverId)
          .eq('status', 'pending');
    } catch (e) {
      print('Error canceling friend request: $e');
      rethrow;
    }
  }
  
  // Upload profile picture
  Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final String filePath = '$userId/$fileName';
      
      // Upload to Supabase Storage
      await _supabase.storage
          .from('avatars')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );
      
      // Get public URL
      final String publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);
      
      // Update profile with picture URL
      await _supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);
      
      return publicUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }
  
  // Delete profile picture
  Future<void> deleteProfilePicture(String userId) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final String filePath = '$userId/$fileName';
      
      // Delete from storage
      await _supabase.storage
          .from('avatars')
          .remove([filePath]);
      
      // Remove URL from profile
      await _supabase
          .from('profiles')
          .update({'avatar_url': null})
          .eq('id', userId);
    } catch (e) {
      print('Error deleting profile picture: $e');
      rethrow;
    }
  }
}
