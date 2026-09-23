import 'package:cloud_firestore/cloud_firestore.dart';

/// Backs "หน้าร้องเรียน / แจ้งปัญหา" (3.3.11) — was previously a form
/// that didn't save anything on submit. Writes to `reports/{id}` so
/// there's a real record an admin (or the examiner) can look up.
class ReportService {
  final FirebaseFirestore _db;
  ReportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> submitReport({
    required String reporterId,
    required String category,
    required String description,
    String? jobId,
    String? evidenceUrl,
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('กรุณากรอกรายละเอียดปัญหา');
    }
    await _db.collection('reports').add({
      'reporter_id': reporterId,
      'category': category,
      'description': description.trim(),
      'job_id': jobId,
      'evidence_url': evidenceUrl,
      'status': 'open', // open, in_review, resolved
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Report history for a user — could back a future "ประวัติการร้องเรียน" list.
  Stream<List<Map<String, dynamic>>> reportsByUser(String reporterId) {
    return _db
        .collection('reports')
        .where('reporter_id', isEqualTo: reporterId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
