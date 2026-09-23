import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
}

/// Backs "ค้นหาและเลือกนักศึกษาผู้รับงาน" (1.3.1.4) — lets multiple
/// students apply to the same job so the employer picks one, instead
/// of first-come-first-served.
class JobApplicationModel {
  final String id;
  final String jobId;
  final String studentId;
  final String status;
  final DateTime? appliedAt;

  const JobApplicationModel({
    required this.id,
    required this.jobId,
    required this.studentId,
    this.status = ApplicationStatus.pending,
    this.appliedAt,
  });

  factory JobApplicationModel.fromMap(String id, Map<String, dynamic> map) {
    return JobApplicationModel(
      id: id,
      jobId: map['job_id'] ?? '',
      studentId: map['student_id'] ?? '',
      status: map['status'] ?? ApplicationStatus.pending,
      appliedAt: (map['applied_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'student_id': studentId,
      'status': status,
      'applied_at': FieldValue.serverTimestamp(),
    };
  }
}
