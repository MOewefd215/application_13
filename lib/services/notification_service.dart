import 'package:cloud_firestore/cloud_firestore.dart';
import 'push_notification_service.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? jobId;
  final String? roomId;
  final String? type;
  final bool read;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.jobId,
    this.roomId,
    this.type,
    this.read = false,
    this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      jobId: map['job_id'] as String?,
      roomId: map['room_id'] as String?,
      type: map['type'] as String?,
      read: map['read'] ?? false,
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

/// Backs "หน้าแจ้งเตือน" (3.3.8) — real Firestore records instead of
/// a permanently-empty list. Actual push delivery (FCM) is a separate
/// concern; this covers the in-app notification center.
class NotificationService {
  final FirebaseFirestore _db;
  NotificationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Future<void> create({
    required String userId,
    required String title,
    required String body,
    String? jobId,
    String? roomId,
    String? type,
  }) async {
    await _col.add({
      'user_id': userId,
      'title': title,
      'body': body,
      if (jobId != null) 'job_id': jobId,
      if (roomId != null) 'room_id': roomId,
      if (type != null) 'type': type,
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    if ((type == 'job' || type == 'review') && jobId != null) {
      await PushNotificationService().sendEventPush(
        type: type!,
        jobId: jobId,
        recipientId: userId,
        title: title,
        body: body,
      );
    }
  }

  Stream<List<NotificationModel>> forUser(String userId, {bool? unreadOnly}) {
    Query<Map<String, dynamic>> query =
        _col.where('user_id', isEqualTo: userId);
    if (unreadOnly == true) {
      query = query.where('read', isEqualTo: false);
    }
    return query.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => NotificationModel.fromMap(d.id, d.data()))
          // Chat alerts belong to the Chat badge only, not this screen.
          .where((notification) => notification.type != 'chat')
          .toList();
      items.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  Stream<int> unreadCountForUser(String userId) {
    return _col
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.where((doc) {
              final data = doc.data();
              return data['read'] != true && data['type'] != 'chat';
            }).length);
  }

  /// Chat notifications are counted separately for the badge on the Chat tab.
  Stream<int> unreadChatCountForUser(String userId) {
    return _col
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.where((doc) {
              final data = doc.data();
              return data['read'] != true && data['type'] == 'chat';
            }).length);
  }

  Future<void> markAsRead(String notificationId) {
    return _col.doc(notificationId).update({'read': true});
  }

  Future<void> markAllAsReadForUser(String userId) async {
    final snapshot = await _col.where('user_id', isEqualTo: userId).get();
    final unread = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['read'] != true && data['type'] != 'chat';
    });
    if (unread.isEmpty) return;

    final batch = _db.batch();
    for (final notification in unread) {
      batch.update(notification.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Marks messages from one conversation as read when that conversation is
  /// actually opened. Merely viewing the chat list must not clear the badge.
  Future<void> markChatRoomAsReadForUser({
    required String userId,
    required String roomId,
  }) async {
    final snapshot = await _col.where('user_id', isEqualTo: userId).get();
    final unreadChat = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['read'] != true &&
          data['type'] == 'chat' &&
          data['room_id'] == roomId;
    });
    if (unreadChat.isEmpty) return;

    final batch = _db.batch();
    for (final notification in unreadChat) {
      batch.update(notification.reference, {'read': true});
    }
    await batch.commit();
  }
}
