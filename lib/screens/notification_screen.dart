import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import 'job_detail_screen.dart';
import '../widgets/bottom_nav.dart';
import '../navigation/app_tab_navigation.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _notificationService = NotificationService();
  final _jobService = JobService();
  bool showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  Future<void> _markNotificationsAsRead() async {
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      await _notificationService.markAllAsReadForUser(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      bottomNavigationBar: StudentProBottomNav(
        currentIndex: 3,
        onTap: (index) => navigateToAppTab(
          context,
          destinationIndex: index,
          currentIndex: 3,
        ),
      ),
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
                                    boxShadow: AppShadows.card,
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
                                    onTap: () => _openNotification(n),
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

  Future<void> _openNotification(NotificationModel notification) async {
    if (!notification.read) {
      await _notificationService.markAsRead(notification.id);
    }
    if (!mounted) return;

    var jobId = notification.jobId;
    if (jobId == null || jobId.isEmpty) {
      final titleMatch = RegExp(r'"([^"]+)"').firstMatch(notification.body);
      if (titleMatch != null) {
        final job = await _jobService.getJobByTitle(titleMatch.group(1)!);
        jobId = job?.jobId;
      }
    }

    if (!mounted) return;
    if (jobId == null || jobId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบงานที่เชื่อมกับการแจ้งเตือนนี้')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(jobId: jobId),
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
          boxShadow: selected ? AppShadows.card : null,
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
