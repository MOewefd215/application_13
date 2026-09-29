import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review_model.dart';
import 'notification_service.dart';

class ReviewSummary {
  final double average;
  final int count;
  const ReviewSummary(this.average, this.count);
}

/// Backs "หน้ารีวิวผู้ใช้งาน" (3.3.12) — was previously a UI-only star
/// picker that didn't save anything. Now writes to Firestore and
/// calculates rating summaries from review documents on the client, without
/// requiring a Cloud Function or a Blaze billing account.
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

    if (FirebaseAuth.instance.currentUser?.uid != reviewerId) {
      throw StateError('กรุณาเข้าสู่ระบบด้วยบัญชีผู้จ้างงานก่อนรีวิว');
    }

    final jobSnapshot = await _db.collection('jobs').doc(jobId).get();
    final job = jobSnapshot.data();
    if (job == null ||
        job['job_status'] != 'Done' ||
        job['emp_id'] != reviewerId ||
        job['std_id'] != revieweeId) {
      throw StateError('ผู้จ้างงานรีวิวได้เฉพาะนักศึกษาที่ทำงานนี้เสร็จแล้ว');
    }
    final review = ReviewModel(
      id: '',
      jobId: jobId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      rating: rating,
      comment: comment,
    );
    final reviewRef = _db.collection('reviews').doc(jobId);
    if ((await reviewRef.get()).exists) {
      throw StateError('งานนี้มีรีวิวแล้ว');
    }
    await reviewRef.set(review.toMap());
    await NotificationService().create(
      userId: revieweeId,
      title: 'คุณได้รับรีวิวใหม่',
      body: 'You received a new review.',
      jobId: jobId,
      type: 'review',
    );
  }

  /// Reviews received by a user — for ProfileScreen / ReviewScreen list.
  Stream<List<ReviewModel>> reviewsForUser(String revieweeId,
      {int limit = 50}) {
    return _db
        .collection('reviews')
        .where('reviewee_id', isEqualTo: revieweeId)
        .snapshots()
        .map((snap) {
      final reviews =
          snap.docs.map((d) => ReviewModel.fromMap(d.id, d.data())).toList();
      reviews.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return reviews.take(limit).toList();
    });
  }

  Stream<ReviewSummary> summaryForUser(String revieweeId) => _db
          .collection('reviews')
          .where('reviewee_id', isEqualTo: revieweeId)
          .snapshots()
          .map((snapshot) {
        final ratings = snapshot.docs
            .map((doc) => (doc.data()['rating'] as num?)?.toInt())
            .whereType<int>()
            .where((rating) => rating >= 1 && rating <= 5)
            .toList();
        if (ratings.isEmpty) return const ReviewSummary(0, 0);
        final total =
            ratings.fold<int>(0, (ratingTotal, rating) => ratingTotal + rating);
        return ReviewSummary(total / ratings.length, ratings.length);
      });
}
