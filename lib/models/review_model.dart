import 'package:cloud_firestore/cloud_firestore.dart';

/// One row in `reviews/{reviewId}` — a rating+comment left by one
/// party about the other after a job is Done (3.3 หน้ารีวิวผู้ใช้งาน).
class ReviewModel {
  final String id;
  final String jobId;
  final String reviewerId;
  final String revieweeId;
  final int rating; // 1-5
  final String comment;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> map) {
    return ReviewModel(
      id: id,
      jobId: map['job_id'] ?? '',
      reviewerId: map['reviewer_id'] ?? '',
      revieweeId: map['reviewee_id'] ?? '',
      rating: (map['rating'] ?? 0) as int,
      comment: map['comment'] ?? '',
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'rating': rating,
      'comment': comment,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
