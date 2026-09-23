import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/job_model.dart';
import '../models/job_application_model.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/chat_service.dart';
import 'job_map_screen.dart';
import 'review_screen.dart';
import 'chat_screen.dart';
import 'post_job_screen.dart';

class JobDetailScreen extends StatefulWidget {
  /// [jobId] is optional so this screen still opens standalone (e.g.
  /// from the UI gallery) — pass it once wired to a real Firestore job.
  final String? jobId;
  final String jobTitle;
  final double? jobLat;
  final double? jobLng;

  const JobDetailScreen({
    super.key,
    this.jobId,
    this.jobTitle = 'ชื่อประกาศงาน',
    this.jobLat,
    this.jobLng,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _jobService = JobService();
  final _authService = AuthService();
  final _chatService = ChatService();

  JobModel? _job;
  bool _loading = false;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) _loadJob();
  }

  Future<void> _loadJob() async {
    setState(() => _loading = true);
    final job = await _jobService.getJob(widget.jobId!);
    if (mounted) {
      setState(() {
        _job = job;
        _loading = false;
      });
    }
  }

  Future<void> _applyToJob() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || widget.jobId == null) return;
    setState(() => _acting = true);
    try {
      await _jobService.applyToJob(jobId: widget.jobId!, stdId: uid);
      if (mounted) {
        setState(() {}); // รีเฟรช FutureBuilder ของ hasApplied
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('สมัครรับงานสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('สมัครไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _selectApplicant(String stdId) async {
    if (_job == null) return;
    setState(() => _acting = true);
    try {
      await _jobService.selectApplicant(jobId: _job!.jobId, stdId: stdId);
      await _loadJob();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('เลือกผู้สมัครสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ทำรายการไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _confirmDone() async {
    if (_job == null) return;
    setState(() => _acting = true);
    try {
      await _jobService.confirmJobDone(_job!.jobId);
      await _loadJob();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ยืนยันงานสำเร็จแล้ว')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ทำรายการไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancelJob() async {
    if (_job == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกงาน'),
        content: const Text('ต้องการยกเลิกงานนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _acting = true);
    try {
      await _jobService.cancelJob(_job!.jobId);
      await _loadJob();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ยกเลิกงานแล้ว')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ทำรายการไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final uid = _authService.currentUser?.uid;
    final isEmployer = job != null && job.empId == uid;
    final title = job?.jobTitle ?? widget.jobTitle;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  color: AppColors.border,
                  child: job?.photoUrl != null
                      ? Image.network(job!.photoUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220)
                      : const Icon(Icons.image_outlined,
                          size: 48, color: AppColors.textSecondary),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleIcon(Icons.arrow_back, () => Navigator.pop(context)),
                      Row(
                        children: [
                          if (isEmployer &&
                              job.jobStatus == JobStatus.open)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _circleIcon(Icons.edit_outlined, () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PostJobScreen(existingJob: job),
                                  ),
                                );
                                if (updated == true) _loadJob();
                              }),
                            ),
                          _circleIcon(Icons.favorite_border, () {}),
                          const SizedBox(width: 8),
                          _circleIcon(Icons.share_outlined, () {}),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              job != null
                                  ? '${job.jobBudget.toStringAsFixed(0)} บาท/ชั่วโมง'
                                  : '- บาท/ชั่วโมง',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            if (job != null) _statusChip(job.jobStatus),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ตกลงวิธีชำระเงินกับอีกฝ่ายโดยตรง (แอปนี้เป็นตัวกลางจับคู่งานเท่านั้น)',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _infoRow(
                            Icons.location_on_outlined,
                            (job?.jobLat != null)
                                ? 'ระบุตำแหน่งบนแผนที่แล้ว'
                                : 'ยังไม่ได้ระบุสถานที่'),
                        _infoRow(Icons.calendar_today_outlined,
                            job?.jobDate ?? 'ยังไม่ได้ระบุวันที่'),
                        _infoRow(Icons.access_time,
                            job?.jobTime ?? 'ยังไม่ได้ระบุเวลา'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobMapScreen(
                                      jobTitle: title,
                                      jobLat: job?.jobLat ?? widget.jobLat,
                                      jobLng: job?.jobLng ?? widget.jobLng,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('ดูแผนที่'),
                              ),
                            ),
                            if (job != null &&
                                job.stdId != null &&
                                uid != null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final otherUid =
                                        isEmployer ? job.stdId! : job.empId;
                                    final roomId = await _chatService.openRoom(
                                      uidA: uid,
                                      uidB: otherUid,
                                      jobId: job.jobId,
                                      jobTitle: job.jobTitle,
                                    );
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ConversationScreen(
                                            roomId: roomId,
                                            otherUserId: otherUid,
                                            title: job.jobTitle,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('แชท'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('รายละเอียดงาน',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          (job?.jobDesc.isNotEmpty ?? false)
                              ? job!.jobDesc
                              : 'ยังไม่มีรายละเอียดงาน',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        if (isEmployer &&
                            job.jobStatus == JobStatus.open) ...[
                          const SizedBox(height: 20),
                          const Text('ผู้สมัครรับงาน',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          StreamBuilder<List<JobApplicationModel>>(
                            stream: _jobService.streamApplicants(job.jobId),
                            builder: (context, snapshot) {
                              final applicants = snapshot.data ?? const [];
                              if (applicants.isEmpty) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.card),
                                    border:
                                        Border.all(color: AppColors.border),
                                  ),
                                  child: const EmptyState(
                                    icon: Icons.people_outline,
                                    message: 'ยังไม่มีนักศึกษาสมัครรับงานนี้',
                                  ),
                                );
                              }
                              return Column(
                                children: applicants.map((app) {
                                  return FutureBuilder<String>(
                                    future: _jobService
                                        .getApplicantName(app.studentId),
                                    builder: (context, nameSnap) {
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.card),
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            const CircleAvatar(
                                              radius: 18,
                                              backgroundColor:
                                                  AppColors.border,
                                              child: Icon(Icons.person,
                                                  size: 18,
                                                  color: AppColors
                                                      .textSecondary),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                  nameSnap.data ??
                                                      'กำลังโหลด...',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  minimumSize:
                                                      const Size(0, 36)),
                                              onPressed: _acting
                                                  ? null
                                                  : () => _selectApplicant(
                                                      app.studentId),
                                              child: const Text('เลือก',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
            ),
            if (job != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildActionButton(job, isEmployer, uid),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(JobModel job, bool isEmployer, String? uid) {
    if (_acting) {
      return const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    // นักศึกษา: งานยังว่าง ยังไม่มีใครรับ → สมัครรับงาน (รอผู้จ้างเลือก)
    if (!isEmployer && job.stdId == null && job.jobStatus == JobStatus.open) {
      if (uid == null) {
        return const ElevatedButton(
            onPressed: null, child: Text('กรุณาเข้าสู่ระบบก่อน'));
      }
      return FutureBuilder<bool>(
        future: _jobService.hasApplied(jobId: job.jobId, stdId: uid),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return const ElevatedButton(
              onPressed: null,
              child: Text('สมัครแล้ว รอผู้จ้างงานพิจารณา'),
            );
          }
          return ElevatedButton(
              onPressed: _applyToJob, child: const Text('สมัครรับงานนี้'));
        },
      );
    }

    // ผู้จ้างงาน: มีนักศึกษารับงานแล้ว กำลังดำเนินการ → ยืนยันเสร็จ / ยกเลิก
    if (isEmployer && job.jobStatus == JobStatus.process) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
                onPressed: _cancelJob, child: const Text('ยกเลิกงาน')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
                onPressed: _confirmDone, child: const Text('ยืนยันงานสำเร็จ')),
          ),
        ],
      );
    }

    // งานเสร็จแล้ว → ให้รีวิวอีกฝ่าย
    if (job.jobStatus == JobStatus.done && uid != null) {
      final revieweeId = isEmployer ? job.stdId : job.empId;
      if (revieweeId != null) {
        return ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewScreen(
                jobId: job.jobId,
                reviewerId: uid,
                revieweeId: revieweeId,
              ),
            ),
          ),
          child: const Text('ให้คะแนนรีวิว'),
        );
      }
    }

    if (isEmployer && job.jobStatus == JobStatus.open) {
      return const ElevatedButton(
        onPressed: null,
        child: Text('เลือกผู้สมัครจากรายชื่อด้านบน'),
      );
    }

    return const ElevatedButton(
      onPressed: null,
      child: Text('ไม่มีการดำเนินการที่ต้องทำตอนนี้'),
    );
  }

  Widget _statusChip(String status) {
    final labelMap = {
      JobStatus.open: 'เปิดรับ',
      JobStatus.process: 'กำลังดำเนินการ',
      JobStatus.done: 'เสร็จสิ้น',
      JobStatus.cancel: 'ยกเลิก',
    };
    return Chip(
      label: Text(labelMap[status] ?? status,
          style: const TextStyle(fontSize: 11)),
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      );

  Widget _infoRow(IconData icon, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}
