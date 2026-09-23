import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _notificationService = NotificationService();
  bool showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('แจ้งเตือน'),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline, message: 'กรุณาเข้าสู่ระบบก่อน')
          : StreamBuilder<List<NotificationModel>>(
              stream: _notificationService.forUser(uid,
                  unreadOnly: showUnreadOnly ? true : null),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _filterButton('ทั้งหมด', !showUnreadOnly,
                                () => setState(() => showUnreadOnly = false)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _filterButton(
                                'ยังไม่ได้อ่าน (${items.where((n) => !n.read).length})',
                                showUnreadOnly,
                                () => setState(() => showUnreadOnly = true)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const EmptyState(
                              icon: Icons.notifications_none,
                              message: 'ยังไม่มีการแจ้งเตือน',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final n = items[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: n.read
                                        ? AppColors.card
                                        : const Color(0xFFEFF4FF),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.card),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      n.read
                                          ? Icons.notifications_none
                                          : Icons.notifications_active,
                                      color: n.read
                                          ? AppColors.textSecondary
                                          : AppColors.blue,
                                    ),
                                    title: Text(n.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(n.body),
                                    onTap: () {
                                      if (!n.read) {
                                        _notificationService.markAsRead(n.id);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _filterButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
