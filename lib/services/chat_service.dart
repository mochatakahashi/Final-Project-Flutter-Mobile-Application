import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // MARK AS READ: Clears the notification badge
  Future<void> markAsRead(String friendId) async {
    final myId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('receiver_id', myId)
        .eq('sender_id', friendId)
        .eq('is_read', false);
  }

  // Legacy method for compatibility
  Future<void> markMessagesAsRead(String senderId) async {
    await markAsRead(senderId);
  }

  // SEND MESSAGE (Text or Image)
  Future<void> sendMessage({
    required String receiverId,
    String? text,
    String? imageUrl,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    await _supabase.from('messages').insert({
      'sender_id': currentUser.id,
      'receiver_id': receiverId,
      'message_text': text ?? '',
      'media_url': imageUrl,
      'is_read': false, // Explicitly set to false for new messages
    });
  }

  // UPLOAD IMAGE TO STORAGE
  Future<String?> uploadChatImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final myId = _supabase.auth.currentUser!.id;
      final path = '$myId/$fileName';

      await _supabase.storage.from('chat_media').upload(path, imageFile);
      return _supabase.storage.from('chat_media').getPublicUrl(path);
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Get real-time message stream for a specific conversation
  Stream<List<Map<String, dynamic>>> getMessagesStream(String otherUserId) {
    final myId = _supabase.auth.currentUser!.id;

    // This stream listens for messages where you are either the sender or receiver
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true) // 👈 MUST be true for bottom-to-top
        .map((data) => data.where((m) => 
            (m['sender_id'] == myId && m['receiver_id'] == otherUserId) ||
            (m['sender_id'] == otherUserId && m['receiver_id'] == myId)
        ).toList());
  }

  // GET CHAT LIST (Recent Conversations)
  Stream<List<Map<String, dynamic>>> getChatListStream() {
    final myId = _supabase.auth.currentUser!.id;
    
    // This query fetches all messages where user is involved
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          // Filter messages where user is sender or receiver
          final userMessages = data.where((m) => 
            m['sender_id'] == myId || m['receiver_id'] == myId
          ).toList();
          
          // Group by conversation (other user's ID)
          final Map<String, Map<String, dynamic>> conversations = {};
          for (var msg in userMessages) {
            final otherId = msg['sender_id'] == myId 
                ? msg['receiver_id'] 
                : msg['sender_id'];
            
            // Keep only the most recent message per conversation
            if (!conversations.containsKey(otherId) || 
                DateTime.parse(msg['created_at']).isAfter(
                  DateTime.parse(conversations[otherId]!['created_at'])
                )) {
              conversations[otherId] = msg;
            }
          }
          
          return conversations.values.toList();
        });
  }

  // Get unread message count from a specific user
  Future<int> getUnreadCount(String senderId) async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('messages')
          .select()
          .eq('sender_id', senderId)
          .eq('receiver_id', myId)
          .eq('is_read', false)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Get total unread message count (for notification badge)
  Future<int> getTotalUnreadCount() async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('messages')
          .select()
          .eq('receiver_id', myId)
          .eq('is_read', false)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting total unread count: $e');
      return 0;
    }
  }
}
