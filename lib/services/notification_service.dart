import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.read = false,
    this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
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
  }) {
    return _col.add({
      'user_id': userId,
      'title': title,
      'body': body,
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
    return query
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> markAsRead(String notificationId) {
    return _col.doc(notificationId).update({'read': true});
  }
}
