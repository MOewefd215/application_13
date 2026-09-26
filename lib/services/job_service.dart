import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_model.dart';
import '../models/job_application_model.dart';
import 'notification_service.dart';

/// Backs "หน้าโพสต์งาน" (post) and "หน้าแรก" (list) — was previously
/// UI-only: the post button did nothing and Home always showed the
/// empty state. Now writes/reads real `jobs/{jobId}` documents
/// matching the JOBS table (ตารางที่ 3.4).
class JobService {
  final FirebaseFirestore _db;
  JobService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');

  Future<String> postJob({
    required String empId,
    required String jobTitle,
    required String jobDesc,
    required double jobBudget,
    double? jobLat,
    double? jobLng,
    String? photoUrl,
    String? jobDate,
    String? jobTime,
    String? jobCategory,
  }) async {
    if (jobTitle.trim().isEmpty) throw ArgumentError('กรุณากรอกหัวข้องาน');
    if (jobBudget <= 0) throw ArgumentError('กรุณาระบุค่าจ้างให้ถูกต้อง');

    final doc = await _jobs.add({
      'job_title': jobTitle.trim(),
      'job_desc': jobDesc.trim(),
      'job_budget': jobBudget,
      'job_lat': jobLat,
      'job_lng': jobLng,
      'job_status': JobStatus.open,
      'emp_id': empId,
      'std_id': null,
      'photo_url': photoUrl,
      'job_date': jobDate,
      'job_time': jobTime,
      'job_category': jobCategory,
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Edits a job the employer already posted — only allowed while it's
  /// still Open (no student assigned yet), so accepted work never
  /// changes under a student's feet.
  Future<void> updateJob({
    required String jobId,
    required String jobTitle,
    required String jobDesc,
    required double jobBudget,
    double? jobLat,
    double? jobLng,
    String? photoUrl,
    String? jobDate,
    String? jobTime,
    String? jobCategory,
  }) async {
    if (jobTitle.trim().isEmpty) throw ArgumentError('กรุณากรอกหัวข้องาน');
    if (jobBudget <= 0) throw ArgumentError('กรุณาระบุค่าจ้างให้ถูกต้อง');

    await _jobs.doc(jobId).update({
      'job_title': jobTitle.trim(),
      'job_desc': jobDesc.trim(),
      'job_budget': jobBudget,
      'job_lat': jobLat,
      'job_lng': jobLng,
      'photo_url': photoUrl,
      'job_date': jobDate,
      'job_time': jobTime,
      'job_category': jobCategory,
    });
  }

  /// Deletes a posted job — only meaningful while still Open.
  Future<void> deleteJob(String jobId) {
    return _jobs.doc(jobId).delete();
  }

  /// Open jobs for the Home feed — "งานแนะนำสำหรับคุณ".
  /// Sorted client-side (not `.orderBy()` in Firestore) so this never
  /// needs a composite index to be created manually in the console.
  Stream<List<JobModel>> streamOpenJobs({int limit = 30}) {
    return _jobs
        .where('job_status', isEqualTo: JobStatus.open)
        .snapshots()
        .map((snap) {
      final jobs =
          snap.docs.map((d) => JobModel.fromMap(d.id, d.data())).toList();
      jobs.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return jobs.take(limit).toList();
    });
  }

  /// A single employer's posted jobs — for "งานที่โพสต์" tab in
  /// Job History.
  Stream<List<JobModel>> streamJobsByEmployer(String empId) {
    return _jobs.where('emp_id', isEqualTo: empId).snapshots().map((snap) {
      final jobs =
          snap.docs.map((d) => JobModel.fromMap(d.id, d.data())).toList();
      jobs.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return jobs;
    });
  }

  /// A single student's accepted jobs — for "งานที่รับ" tab.
  Stream<List<JobModel>> streamJobsByStudent(String stdId) {
    return _jobs.where('std_id', isEqualTo: stdId).snapshots().map((snap) {
      final jobs =
          snap.docs.map((d) => JobModel.fromMap(d.id, d.data())).toList();
      jobs.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return jobs;
    });
  }

  CollectionReference<Map<String, dynamic>> get _applications =>
      _db.collection('job_applications');

  /// Student applies to an open job — job stays Open, multiple
  /// students can apply, employer picks one later via
  /// [selectApplicant]. Replaces the old first-come-first-served
  /// `acceptJob`.
  Future<void> applyToJob({required String jobId, required String stdId}) async {
    final already = await hasApplied(jobId: jobId, stdId: stdId);
    if (already) throw StateError('คุณสมัครงานนี้ไปแล้ว');

    final job = await getJob(jobId);
    if (job == null) throw StateError('ไม่พบงานนี้');
    if (job.jobStatus != JobStatus.open) {
      throw StateError('งานนี้ไม่เปิดรับสมัครแล้ว');
    }

    await _applications.add(JobApplicationModel(
      id: '',
      jobId: jobId,
      studentId: stdId,
    ).toMap());

    await NotificationService().create(
      userId: job.empId,
      title: 'มีผู้สมัครงานใหม่',
      body: 'งาน "${job.jobTitle}" มีนักศึกษาสมัครรับงานเพิ่ม',
    );
  }

  Future<bool> hasApplied({required String jobId, required String stdId}) async {
    final snap = await _applications
        .where('job_id', isEqualTo: jobId)
        .where('student_id', isEqualTo: stdId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// All applicants for a job — for the employer to choose from.
  Stream<List<JobApplicationModel>> streamApplicants(String jobId) {
    return _applications
        .where('job_id', isEqualTo: jobId)
        .snapshots()
        .map((snap) {
      final apps = snap.docs
          .map((d) => JobApplicationModel.fromMap(d.id, d.data()))
          .toList();
      apps.sort((a, b) => (a.appliedAt ?? DateTime(0))
          .compareTo(b.appliedAt ?? DateTime(0)));
      return apps;
    });
  }

  /// All applications a student has sent, across every job — for
  /// "คำขอที่ส่งไป" so students can track pending/accepted/rejected
  /// status without digging through Home.
  Stream<List<JobApplicationModel>> streamMyApplications(String stdId) {
    return _applications
        .where('student_id', isEqualTo: stdId)
        .snapshots()
        .map((snap) {
      final apps = snap.docs
          .map((d) => JobApplicationModel.fromMap(d.id, d.data()))
          .toList();
      apps.sort((a, b) => (b.appliedAt ?? DateTime(0))
          .compareTo(a.appliedAt ?? DateTime(0)));
      return apps;
    });
  }

  /// Best-effort applicant display name — reads `students/{uid}`.
  Future<String> getApplicantName(String studentId) async {
    final snap = await _db.collection('students').doc(studentId).get();
    final name = snap.data()?['std_fullname'] as String?;
    return (name == null || name.isEmpty) ? 'นักศึกษา' : name;
  }

  /// Employer picks one applicant — job moves to Process, other
  /// pending applications on the same job are marked rejected.
  Future<void> selectApplicant({
    required String jobId,
    required String stdId,
  }) async {
    final job = await getJob(jobId);
    if (job == null) throw StateError('ไม่พบงานนี้');
    if (job.jobStatus != JobStatus.open) {
      throw StateError('งานนี้ไม่อยู่ในสถานะที่เลือกผู้สมัครได้');
    }

    await _jobs.doc(jobId).update({
      'std_id': stdId,
      'job_status': JobStatus.process,
    });

    final applicants = await _applications
        .where('job_id', isEqualTo: jobId)
        .get();
    final batch = _db.batch();
    for (final doc in applicants.docs) {
      final isChosen = doc.data()['student_id'] == stdId;
      batch.update(doc.reference, {
        'status': isChosen
            ? ApplicationStatus.accepted
            : ApplicationStatus.rejected,
      });
    }
    await batch.commit();

    await NotificationService().create(
      userId: stdId,
      title: 'คุณได้รับเลือกให้ทำงานนี้',
      body: 'งาน "${job.jobTitle}" เลือกคุณเป็นผู้รับงานแล้ว',
    );
  }

  /// Employer confirms the work is done — job_status = Done.
  /// Notifies the student. No money moves through the app.
  Future<void> confirmJobDone(String jobId) async {
    final job = await getJob(jobId);
    if (job == null) throw StateError('ไม่พบงานนี้');
    await _jobs.doc(jobId).update({'job_status': JobStatus.done});
    if (job.stdId != null) {
      await NotificationService().create(
        userId: job.stdId!,
        title: 'งานเสร็จสิ้นแล้ว',
        body: 'งาน "${job.jobTitle}" ถูกยืนยันว่าเสร็จสิ้นแล้ว',
      );
    }
  }

  /// Employer or student cancels an in-progress job — job_status = Cancel.
  Future<void> cancelJob(String jobId) async {
    final job = await getJob(jobId);
    if (job == null) throw StateError('ไม่พบงานนี้');
    await _jobs.doc(jobId).update({'job_status': JobStatus.cancel});
    if (job.stdId != null) {
      await NotificationService().create(
        userId: job.stdId!,
        title: 'งานถูกยกเลิก',
        body: 'งาน "${job.jobTitle}" ถูกยกเลิกแล้ว',
      );
    }
  }

  Future<JobModel?> getJob(String jobId) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return null;
    return JobModel.fromMap(snap.id, snap.data()!);
  }
}
