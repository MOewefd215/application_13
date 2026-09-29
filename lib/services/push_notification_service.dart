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
import '../theme/app_theme.dart';

/// Push delivery configuration. This URL contains no secret; the Worker
/// authenticates each request with the signed-in Firebase user's ID token.
class PushNotificationService {
  static const _workerBaseUrl = 'https://studentpro-push.mi-qwex04.workers.dev';

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static OverlayEntry? _foregroundBanner;
  static Timer? _foregroundBannerTimer;

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
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_showForegroundBanner);
    await _openedSubscription?.cancel();
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _openMessage(initialMessage);
  }

  static void _showForegroundBanner(RemoteMessage message) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _dismissForegroundBanner();
    final type = message.data['type'] as String? ?? 'chat';
    final title = message.notification?.title ??
        (type == 'chat' ? 'ข้อความใหม่' : 'มีการแจ้งเตือนใหม่');
    final body = message.notification?.body ??
        (type == 'chat' ? 'คุณได้รับข้อความแชตใหม่' : 'แตะเพื่อดูรายละเอียด');
    final icon = switch (type) {
      'job' => Icons.work_outline_rounded,
      'review' => Icons.star_outline_rounded,
      _ => Icons.chat_bubble_outline_rounded,
    };

    _foregroundBanner = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: TweenAnimationBuilder<Offset>(
              tween: Tween(begin: const Offset(0, -1.15), end: Offset.zero),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) => FractionalTranslation(
                translation: offset,
                child: child,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    _dismissForegroundBanner();
                    PushNotificationService()._openMessage(message);
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.floating,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.paleBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: AppColors.navyDark, size: 23),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 3),
                              Text(body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.35,
                                  )),
                            ],
                          ),
                        ),
                        const IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'ปิดการแจ้งเตือน',
                          onPressed: _dismissForegroundBanner,
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_foregroundBanner!);
    _foregroundBannerTimer = Timer(
      const Duration(seconds: 5),
      _dismissForegroundBanner,
    );
  }

  static void _dismissForegroundBanner() {
    _foregroundBannerTimer?.cancel();
    _foregroundBannerTimer = null;
    _foregroundBanner?.remove();
    _foregroundBanner?.dispose();
    _foregroundBanner = null;
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
      final response = await http.post(
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
      if (response.statusCode != 200) {
        debugPrint(
            'Push Worker returned ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      debugPrint('Push request failed: $error');
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
      final response = await http.post(
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
      if (response.statusCode != 200) {
        debugPrint(
            'Push Worker returned ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      debugPrint('Push request failed: $error');
      // Firestore notification records remain available if push is offline.
    }
  }
}
