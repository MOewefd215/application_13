import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../models/job_model.dart';
import '../models/job_application_model.dart';
import '../models/user_role.dart';
import 'job_detail_screen.dart';

enum _StudentTab { received, applications }

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});

  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  final _jobService = JobService();
  final _authService = AuthService();
  _StudentTab _studentTab = _StudentTab.received;

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

          if (isEmployer) {
            return Column(
              children: [
                Expanded(child: _postedJobsList(uid)),
                _earningsSummary(uid, isEmployer: true),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _tabButton(
                          'งานที่รับ',
                          _studentTab == _StudentTab.received,
                          () => setState(
                              () => _studentTab = _StudentTab.received)),
                    ),
                    Expanded(
                      child: _tabButton(
                          'คำขอที่ส่งไป',
                          _studentTab == _StudentTab.applications,
                          () => setState(
                              () => _studentTab = _StudentTab.applications)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _studentTab == _StudentTab.received
                    ? _receivedJobsList(uid)
                    : _myApplicationsList(uid),
              ),
              if (_studentTab == _StudentTab.received)
                _earningsSummary(uid, isEmployer: false),
            ],
          );
        },
      ),
    );
  }

  Widget _postedJobsList(String uid) {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.streamJobsByEmployer(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final jobs = snapshot.data ?? const [];
        if (jobs.isEmpty) {
          return const EmptyState(
              icon: Icons.history, message: 'ยังไม่มีประวัติการทำงาน');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          itemBuilder: (context, index) => _jobTile(context, jobs[index]),
        );
      },
    );
  }

  Widget _receivedJobsList(String uid) {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.streamJobsByStudent(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final jobs = snapshot.data ?? const [];
        if (jobs.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            message: 'ยังไม่มีงานที่ได้รับเลือก',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          itemBuilder: (context, index) => _jobTile(context, jobs[index]),
        );
      },
    );
  }

  /// แท็บ "คำขอที่ส่งไป" — แก้ปัญหา "กดสมัครแล้วงานหายไปไหน" ให้
  /// นักศึกษาเห็นสถานะคำขอทุกใบของตัวเองที่นี่.
  Widget _myApplicationsList(String uid) {
    return StreamBuilder<List<JobApplicationModel>>(
      stream: _jobService.streamMyApplications(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final applications = snapshot.data ?? const [];
        if (applications.isEmpty) {
          return const EmptyState(
            icon: Icons.send_outlined,
            message: 'ยังไม่เคยสมัครงานใด ๆ',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) =>
              _applicationTile(context, applications[index]),
        );
      },
    );
  }

  Widget _applicationTile(BuildContext context, JobApplicationModel app) {
    final statusInfo = {
          ApplicationStatus.pending: (
            'รอผู้จ้างงานพิจารณา',
            AppColors.textSecondary
          ),
          ApplicationStatus.accepted: ('ได้รับเลือกแล้ว', AppColors.success),
          ApplicationStatus.rejected: ('ไม่ได้รับเลือก', AppColors.danger),
        }[app.status] ??
        (app.status, AppColors.textSecondary);

    return FutureBuilder<JobModel?>(
      future: _jobService.getJob(app.jobId),
      builder: (context, jobSnap) {
        final job = jobSnap.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            onTap: job == null
                ? null
                : () => Navigator.push(
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
                      Text(job?.jobTitle ?? 'กำลังโหลด...',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(statusInfo.$1,
                          style:
                              TextStyle(fontSize: 12, color: statusInfo.$2)),
                    ],
                  ),
                ),
                if (job != null)
                  Text('${job.jobBudget.toStringAsFixed(0)} บาท',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
      },
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

  Widget _earningsSummary(String uid, {required bool isEmployer}) {
    return StreamBuilder<List<JobModel>>(
      stream: isEmployer
          ? _jobService.streamJobsByEmployer(uid)
          : _jobService.streamJobsByStudent(uid),
      builder: (context, snapshot) {
        final jobs = (snapshot.data ?? const [])
            .where((j) => j.jobStatus == JobStatus.done);
        final total = jobs.fold<double>(0, (sum, j) => sum + j.jobBudget);

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
