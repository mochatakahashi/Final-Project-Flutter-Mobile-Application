import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../main.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _profileService = ProfileService();

  Future<Map<String, dynamic>> _enrichChatData(Map<String, dynamic> message) async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final otherId = message['sender_id'] == myId 
        ? message['receiver_id'] 
        : message['sender_id'];

    // Fetch friend profile
    try {
      final profile = await _profileService.getProfileById(otherId);
      final friendName = profile?['full_name'] ?? 'Unknown User';

      // Get unread count
      final unreadCount = await _chatService.getUnreadCount(otherId);

      // Format timestamp
      final timestamp = message['created_at'] as String?;
      String timeStr = '';
      if (timestamp != null) {
        final time = DateTime.parse(timestamp);
        final now = DateTime.now();
        final diff = now.difference(time);

        if (diff.inDays > 0) {
          timeStr = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeStr = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeStr = '${diff.inMinutes}m ago';
        } else {
          timeStr = 'Just now';
        }
      }

      return {
        ...message,
        'friend_id': otherId,
        'friend_name': friendName,
        'unread_count': unreadCount,
        'time_str': timeStr,
      };
    } catch (e) {
      print('Error enriching chat data: $e');
      return {
        ...message,
        'friend_id': otherId,
        'friend_name': 'Unknown User',
        'unread_count': 0,
        'time_str': '',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade700,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getChatListStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading conversations',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start chatting with your friends!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(chats.map((chat) => _enrichChatData(chat))),
            builder: (context, enrichedSnapshot) {
              if (!enrichedSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final enrichedChats = enrichedSnapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: enrichedChats.length,
                itemBuilder: (context, index) {
                  final chat = enrichedChats[index];
                  final friendName = chat['friend_name'] as String;
                  final friendId = chat['friend_id'] as String;
                  final messageText = chat['message_text'] as String? ?? '';
                  final mediaUrl = chat['media_url'] as String?;
                  final unreadCount = chat['unread_count'] as int;
                  final timeStr = chat['time_str'] as String;
                  final isMyMessage = chat['sender_id'] == Supabase.instance.client.auth.currentUser!.id;

                  String subtitle;
                  if (mediaUrl != null && mediaUrl.isNotEmpty) {
                    subtitle = isMyMessage ? 'You: 📷 Image' : '📷 Image';
                  } else if (messageText.isNotEmpty) {
                    subtitle = isMyMessage ? 'You: $messageText' : messageText;
                  } else {
                    subtitle = 'No messages yet';
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purple.shade300,
                        ),
                        child: Center(
                          child: Text(
                            friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        friendName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: unreadCount > 0 ? Colors.purple.shade700 : Colors.grey.shade500,
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.purple.shade700,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        // Navigate to ChatScreen with this friend
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              friendId: friendId,
                              friendName: friendName,
                            ),
                          ),
                        ).then((_) {
                          // Refresh the chat list when returning
                          setState(() {});
                        });
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
