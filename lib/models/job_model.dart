import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the `JOBS` table from the ER diagram (รูปที่ 3.2.4) in the thesis:
/// job_id, job_title, job_desc, job_budget, job_lat, job_lng,
/// job_status, emp_id, std_id.
///
/// job_status values follow the flowchart's shape (Open, Process, Done,
/// Cancel) but the app no longer moves any money through the system —
/// job_budget is shown as reference info only ("ระบุค่าจ้าง" per the
/// thesis scope 1.3), and employer/student are expected to settle
/// payment between themselves outside the app.
class JobStatus {
  static const String open = 'Open';
  static const String process = 'Process';
  static const String done = 'Done';
  static const String cancel = 'Cancel';
}

class JobModel {
  final String jobId;
  final String jobTitle;
  final String jobDesc;
  final double jobBudget;
  final double? jobLat;
  final double? jobLng;
  final String jobStatus;
  final String empId;
  final String? stdId;
  final String? photoUrl;
  final String? jobDate; // เก็บเป็น "yyyy-MM-dd" — แสดงในหน้ารายละเอียดงาน
  final String? jobTime; // เก็บเป็น "HH:mm - HH:mm"
  final String? jobCategory;
  final DateTime? createdAt;

  const JobModel({
    required this.jobId,
    required this.jobTitle,
    required this.jobDesc,
    required this.jobBudget,
    this.jobLat,
    this.jobLng,
    required this.jobStatus,
    required this.empId,
    this.stdId,
    this.photoUrl,
    this.jobDate,
    this.jobTime,
    this.jobCategory,
    this.createdAt,
  });

  factory JobModel.fromMap(String id, Map<String, dynamic> map) {
    return JobModel(
      jobId: id,
      jobTitle: map['job_title'] ?? '',
      jobDesc: map['job_desc'] ?? '',
      jobBudget: (map['job_budget'] ?? 0).toDouble(),
      jobLat: map['job_lat']?.toDouble(),
      jobLng: map['job_lng']?.toDouble(),
      jobStatus: map['job_status'] ?? JobStatus.open,
      empId: map['emp_id'] ?? '',
      stdId: map['std_id'],
      photoUrl: map['photo_url'],
      jobDate: map['job_date'],
      jobTime: map['job_time'],
      jobCategory: map['job_category'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'job_title': jobTitle,
      'job_desc': jobDesc,
      'job_budget': jobBudget,
      'job_lat': jobLat,
      'job_lng': jobLng,
      'job_status': jobStatus,
      'emp_id': empId,
      'std_id': stdId,
      'photo_url': photoUrl,
      'job_date': jobDate,
      'job_time': jobTime,
      'job_category': jobCategory,
    };
  }
}
