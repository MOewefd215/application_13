import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessageModel(
      id: id,
      senderId: map['sender_id'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'text': text,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}

/// One row per chat room, used for the conversation list screen.
class ChatRoomModel {
  final String id; // deterministic: sorted uid pair joined with "_"
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? jobId;
  final String? jobTitle;

  const ChatRoomModel({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageAt,
    this.jobId,
    this.jobTitle,
  });

  factory ChatRoomModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatRoomModel(
      id: id,
      participantIds: List<String>.from(map['participant_ids'] ?? []),
      lastMessage: map['last_message'],
      lastMessageAt: (map['last_message_at'] as Timestamp?)?.toDate(),
      jobId: map['job_id'],
      jobTitle: map['job_title'],
    );
  }

  String otherParticipant(String myUid) =>
      participantIds.firstWhere((id) => id != myUid, orElse: () => '');
}
