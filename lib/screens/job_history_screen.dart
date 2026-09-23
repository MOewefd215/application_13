import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../models/job_model.dart';
import '../models/user_role.dart';
import 'job_detail_screen.dart';

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});

  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  final _jobService = JobService();
  final _authService = AuthService();
  bool showReceived = true; // นักศึกษา: งานที่รับ / ผู้จ้างงาน: งานที่โพสต์

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid;

    return Scaffold(
      bottomNavigationBar: StudentProBottomNav(currentIndex: 1, onTap: (_) {}),
      appBar: AppBar(title: const Text('ประวัติการทำงาน')),
      body: FutureBuilder<String?>(
        future: _authService.getUserRole(),
        builder: (context, roleSnap) {
          if (!roleSnap.hasData || uid == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final isEmployer = roleSnap.data == UserRole.employer;

          return Column(
            children: [
              if (!isEmployer)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabButton('งานที่รับ', showReceived,
                            () => setState(() => showReceived = true)),
                      ),
                      Expanded(
                        child: _tabButton('งานที่โพสต์', !showReceived,
                            () => setState(() => showReceived = false)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<JobModel>>(
                  stream: isEmployer
                      ? _jobService.streamJobsByEmployer(uid)
                      : (showReceived
                          ? _jobService.streamJobsByStudent(uid)
                          : _jobService.streamJobsByEmployer(uid)),
                  builder: (context, snapshot) {
                    final jobs = snapshot.data ?? const [];
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (jobs.isEmpty) {
                      return const EmptyState(
                        icon: Icons.history,
                        message: 'ยังไม่มีประวัติการทำงาน',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: jobs.length,
                      itemBuilder: (context, index) =>
                          _jobTile(context, jobs[index]),
                    );
                  },
                ),
              ),
              _earningsSummary(uid, isEmployer),
            ],
          );
        },
      ),
    );
  }

  Widget _jobTile(BuildContext context, JobModel job) {
    final statusLabel = {
          JobStatus.open: 'เปิดรับ',
          JobStatus.process: 'กำลังดำเนินการ',
          JobStatus.done: 'เสร็จสิ้น',
          JobStatus.cancel: 'ยกเลิก',
        }[job.jobStatus] ??
        job.jobStatus;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => JobDetailScreen(
                    jobId: job.jobId, jobTitle: job.jobTitle))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.jobTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${job.jobBudget.toStringAsFixed(0)} บาท',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Chip(
              label: Text(statusLabel, style: const TextStyle(fontSize: 11)),
              backgroundColor: AppColors.background,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _earningsSummary(String uid, bool isEmployer) {
    return StreamBuilder<List<JobModel>>(
      stream: isEmployer
          ? _jobService.streamJobsByEmployer(uid)
          : _jobService.streamJobsByStudent(uid),
      builder: (context, snapshot) {
        final jobs = (snapshot.data ?? const [])
            .where((j) => j.jobStatus == JobStatus.done);
        final total = jobs.fold<double>(
            0,
            (sum, j) =>
                sum + j.jobBudget);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(isEmployer ? 'ยอดจ่ายทั้งหมด' : 'รายได้รวมทั้งหมด',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('${total.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.navy : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.navy : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
