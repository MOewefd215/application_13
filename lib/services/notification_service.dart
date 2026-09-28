import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? jobId;
  final bool read;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.jobId,
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
  }) {
    return _col.add({
      'user_id': userId,
      'title': title,
      'body': body,
      if (jobId != null) 'job_id': jobId,
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
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
          .toList();
      items.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  Stream<int> unreadCountForUser(String userId) {
    return _col
        .where('user_id', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markAsRead(String notificationId) {
    return _col.doc(notificationId).update({'read': true});
  }

  Future<void> markAllAsReadForUser(String userId) async {
    final unread = await _col
        .where('user_id', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;

    final batch = _db.batch();
    for (final notification in unread.docs) {
      batch.update(notification.reference, {'read': true});
    }
    await batch.commit();
  }
}
