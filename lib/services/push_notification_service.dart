import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

/// Push delivery configuration. This URL contains no secret; the Worker
/// authenticates each request with the signed-in Firebase user's ID token.
class PushNotificationService {
  static const _workerBaseUrl =
      'https://studentpro-push.mi-qwex04.workers.dev';

  static StreamSubscription<String>? _tokenRefreshSubscription;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Requests permission on Android 13+ and writes this device's token to
  /// `devices/{uid}`. Call after the user has signed in.
  Future<void> enableForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) await _saveToken(user.uid, token);

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (newToken) => _saveToken(user.uid, newToken),
    );
  }

  Future<void> _saveToken(String uid, String token) {
    return _db.collection('devices').doc(uid).set({
      'fcm_token': token,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Best-effort only: a successful chat message must not fail just because
  /// push delivery is unavailable or the recipient has not enabled it yet.
  Future<void> sendChatPush({
    required String roomId,
    required String recipientId,
    required String body,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final idToken = await user.getIdToken();
      if (idToken == null) return;
      await http.post(
        Uri.parse('$_workerBaseUrl/send'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'roomId': roomId,
          'recipientId': recipientId,
          'title': 'มีข้อความแชตใหม่',
          'body': body,
        }),
      );
    } catch (_) {
      // Firestore chat still works if the optional push service is unavailable.
    }
  }
}
