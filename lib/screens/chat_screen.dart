import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../models/chat_models.dart';

/// Chat list screen — real conversations from Firestore.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('แชท')),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline, message: 'กรุณาเข้าสู่ระบบก่อน')
          : StreamBuilder<List<ChatRoomModel>>(
              stream: ChatService().roomsForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rooms = snapshot.data ?? const [];
                if (rooms.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    message: 'ยังไม่มีบทสนทนา',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.border,
                          child: Icon(Icons.person,
                              color: AppColors.textSecondary),
                        ),
                        title: Text(room.jobTitle ?? 'บทสนทนา'),
                        subtitle: Text(
                          room.lastMessage ?? 'ยังไม่มีข้อความ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              roomId: room.id,
                              otherUserId: room.otherParticipant(uid),
                              title: room.jobTitle ?? 'บทสนทนา',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// A single conversation — real-time messages via ChatService.
class ConversationScreen extends StatefulWidget {
  /// All optional so this screen still opens standalone (UI gallery).
  /// Pass real values when navigating from a chat room or job detail.
  final String? roomId;
  final String? otherUserId;
  final String title;

  const ConversationScreen({
    super.key,
    this.roomId,
    this.otherUserId,
    this.title = 'ชื่อผู้สนทนา',
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || widget.roomId == null) return;
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    _messageController.clear();
    await _chatService.sendMessage(
        roomId: widget.roomId!, senderId: uid, text: text);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.border,
              child:
                  Icon(Icons.person, color: AppColors.textSecondary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.title,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.roomId == null
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    message: 'เริ่มต้นบทสนทนาของคุณ',
                  )
                : StreamBuilder<List<ChatMessageModel>>(
                    stream: _chatService.messagesInRoom(widget.roomId!),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const [];
                      if (messages.isEmpty) {
                        return const EmptyState(
                          icon: Icons.forum_outlined,
                          message: 'เริ่มต้นบทสนทนาของคุณ',
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent);
                        }
                      });
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == myUid;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.navy : AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: isMe
                                    ? null
                                    : Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : AppColors.textPrimary),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration:
                        const InputDecoration(hintText: 'พิมพ์ข้อความ...'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
