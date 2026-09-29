import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../navigation/app_navigation.dart';
import '../screens/job_detail_screen.dart';
import '../screens/chat_screen.dart';

/// Push delivery configuration. This URL contains no secret; the Worker
/// authenticates each request with the signed-in Firebase user's ID token.
class PushNotificationService {
  static const _workerBaseUrl = 'https://studentpro-push.mi-qwex04.workers.dev';

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;

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
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final context = appNavigatorKey.currentContext;
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (context != null &&
          context.mounted &&
          (title != null || body != null)) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
              content: Text([title, body].whereType<String>().join(' - '))),
        );
      }
    });
    await _openedSubscription?.cancel();
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _openMessage(initialMessage);
  }

  void _openMessage(RemoteMessage message) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final roomId = message.data['roomId'] as String?;
    if (roomId != null && roomId.isNotEmpty) {
      navigator.push(MaterialPageRoute(
        builder: (_) => ConversationScreen(
            roomId: roomId, title: message.notification?.title ?? 'Chat'),
      ));
      return;
    }
    final jobId = message.data['jobId'] as String?;
    if (jobId != null && jobId.isNotEmpty) {
      navigator.push(MaterialPageRoute(
        builder: (_) => JobDetailScreen(jobId: jobId),
      ));
    }
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

  /// Best-effort push for a job or review event. The Worker verifies that
  /// both users belong to the job, and verifies review authorship for reviews.
  Future<void> sendEventPush({
    required String type,
    required String jobId,
    required String recipientId,
    required String title,
    required String body,
  }) async {
    final user = _auth.currentUser;
    if (user == null || (type != 'job' && type != 'review')) return;
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
          'type': type,
          'jobId': jobId,
          'recipientId': recipientId,
          'title': title,
          'body': body,
        }),
      );
    } catch (_) {
      // Firestore notification records remain available if push is offline.
    }
  }
}
