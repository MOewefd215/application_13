import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

/// Backs "หน้ารีวิวผู้ใช้งาน" (3.3.12) — was previously a UI-only star
/// picker that didn't save anything. Now writes to Firestore and
/// keeps `std_rating` (ตารางที่ 3.3) up to date so the badge shown on
/// ProfileScreen/JobDetail reflects real reviews.
class ReviewService {
  final FirebaseFirestore _db;
  ReviewService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> submitReview({
    required String jobId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    required String comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('คะแนนต้องอยู่ระหว่าง 1-5');
    }

    final review = ReviewModel(
      id: '',
      jobId: jobId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      rating: rating,
      comment: comment,
    );
    await _db.collection('reviews').add(review.toMap());

    await _recalculateAverageRating(revieweeId);
  }

  Future<void> _recalculateAverageRating(String revieweeId) async {
    final snap = await _db
        .collection('reviews')
        .where('reviewee_id', isEqualTo: revieweeId)
        .get();
    if (snap.docs.isEmpty) return;

    final ratings =
        snap.docs.map((d) => (d.data()['rating'] as num).toDouble());
    final average = ratings.reduce((a, b) => a + b) / ratings.length;

    // เขียนกลับที่ students/{uid} — เผื่อ revieweeId ไม่ใช่นักศึกษา
    // (เช่นรีวิวผู้จ้างงาน) การ set แบบ merge จะไม่พังอะไร แค่ไม่มีผล
    await _db
        .collection('students')
        .doc(revieweeId)
        .set({'std_rating': average}, SetOptions(merge: true))
        .catchError((_) {});
  }

  /// Reviews received by a user — for ProfileScreen / ReviewScreen list.
  Stream<List<ReviewModel>> reviewsForUser(String revieweeId,
      {int limit = 50}) {
    return _db
        .collection('reviews')
        .where('reviewee_id', isEqualTo: revieweeId)
        .snapshots()
        .map((snap) {
      final reviews = snap.docs
          .map((d) => ReviewModel.fromMap(d.id, d.data()))
          .toList();
      reviews.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return reviews.take(limit).toList();
    });
  }
}
