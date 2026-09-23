import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';

/// Real-time chat backing "หน้าแชท" (3.3.4) — restores working
/// employer <-> student messaging using a deterministic chatRoomId
/// (sorted uid pair) plus a `messages` subcollection.
class ChatService {
  final FirebaseFirestore _db;
  ChatService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static String chatRoomId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('chat_rooms');

  Future<String> openRoom({
    required String uidA,
    required String uidB,
    String? jobId,
    String? jobTitle,
  }) async {
    final roomId = chatRoomId(uidA, uidB);
    final doc = _rooms.doc(roomId);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'participant_ids': [uidA, uidB],
        'job_id': jobId,
        'job_title': jobTitle,
        'last_message': null,
        'last_message_at': FieldValue.serverTimestamp(),
      });
    }
    return roomId;
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final message =
        ChatMessageModel(id: '', senderId: senderId, text: text.trim());
    await _rooms.doc(roomId).collection('messages').add(message.toMap());
    await _rooms.doc(roomId).set({
      'last_message': text.trim(),
      'last_message_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ChatMessageModel>> messagesInRoom(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessageModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<ChatRoomModel>> roomsForUser(String uid) {
    return _rooms
        .where('participant_ids', arrayContains: uid)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatRoomModel.fromMap(d.id, d.data()))
            .toList());
  }
}
