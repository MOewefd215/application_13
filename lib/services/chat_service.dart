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

  Future<void> sendImageMessage({
    required String roomId,
    required String senderId,
    required String imageUrl,
  }) async {
    await _rooms.doc(roomId).collection('messages').add({
      'sender_id': senderId,
      'image_url': imageUrl,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _rooms.doc(roomId).set({
      'last_message': '[Image]',
      'last_message_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendAudioMessage({
    required String roomId,
    required String senderId,
    required String audioUrl,
    required int durationMs,
  }) async {
    await _rooms.doc(roomId).collection('messages').add({
      'sender_id': senderId,
      'audio_url': audioUrl,
      'audio_duration_ms': durationMs,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _rooms.doc(roomId).set({
      'last_message': '[Voice message]',
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
        .snapshots()
        .map((snap) {
      final rooms =
          snap.docs.map((d) => ChatRoomModel.fromMap(d.id, d.data())).toList();
      rooms.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
          .compareTo(a.lastMessageAt ?? DateTime(0)));
      return rooms;
    });
  }
}
