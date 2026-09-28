import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class StudentProBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const StudentProBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    final unreadCount = uid == null
        ? Stream<int>.value(0)
        : NotificationService().unreadCountForUser(uid);

    return StreamBuilder<int>(
      stream: unreadCount,
      initialData: 0,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.floating,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Row(
                  children: [
                    _destination(0, Icons.home_rounded, 'หน้าหลัก'),
                    _destination(1, Icons.work_outline_rounded, 'งานของฉัน'),
                    _chatDestination(),
                    _destination(
                      3,
                      Icons.notifications_none_rounded,
                      'แจ้งเตือน',
                      badgeCount: unread,
                    ),
                    _destination(4, Icons.person_outline_rounded, 'โปรไฟล์'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _destination(
    int index,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) {
    final selected = currentIndex == index;
    final foreground = selected ? Colors.white : AppColors.textSecondary;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
            decoration: BoxDecoration(
              color: selected ? AppColors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconWithBadge(badgeCount, icon, foreground),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 9,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatDestination() {
    final uid = AuthService().currentUser?.uid;
    final unreadChat = uid == null
        ? Stream<int>.value(0)
        : NotificationService().unreadChatCountForUser(uid);

    return StreamBuilder<int>(
      stream: unreadChat,
      initialData: 0,
      builder: (context, snapshot) => _destination(
        2,
        Icons.chat_bubble_outline_rounded,
        'แชท',
        badgeCount: snapshot.data ?? 0,
      ),
    );
  }

  Widget _iconWithBadge(int count, IconData icon, Color color) {
    final iconWidget = Icon(icon, color: color, size: 20);
    if (count == 0) return iconWidget;
    return Badge(
      backgroundColor: AppColors.danger,
      label: Text(count > 99 ? '99+' : '$count'),
      child: iconWidget,
    );
  }
}
