import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/review_service.dart';
import '../models/review_model.dart';

class ReviewScreen extends StatefulWidget {
  /// All optional so this screen still opens standalone (UI gallery).
  /// Pass real values once wired from JobDetailScreen, e.g.
  /// `ReviewScreen(jobId: job.jobId, reviewerId: uid, revieweeId: otherUid)`.
  final String? jobId;
  final String? reviewerId;
  final String? revieweeId;

  const ReviewScreen({
    super.key,
    this.jobId,
    this.reviewerId,
    this.revieweeId,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _reviewService = ReviewService();
  final _commentController = TextEditingController();
  int selectedStars = 0;
  bool _submitting = false;

  bool get _canSubmit =>
      widget.jobId != null && widget.reviewerId != null && widget.revieweeId != null;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (selectedStars == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาให้คะแนนก่อนส่งรีวิว')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _reviewService.submitReview(
        jobId: widget.jobId!,
        reviewerId: widget.reviewerId!,
        revieweeId: widget.revieweeId!,
        rating: selectedStars,
        comment: _commentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ส่งรีวิวสำเร็จ')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ส่งรีวิวไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รีวิว')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.border,
            child: Icon(Icons.person, size: 32, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('ให้คะแนนรีวิวหลังจบงาน',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < selectedStars ? Icons.star : Icons.star_border,
                  color: AppColors.star,
                  size: 32,
                ),
                onPressed: () => setState(() => selectedStars = index + 1),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'เขียนรีวิวของคุณ...'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (_canSubmit && !_submitting) ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('ส่งรีวิว'),
          ),
          const SizedBox(height: 28),
          const Text('รีวิวทั้งหมด',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (widget.revieweeId == null)
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: const EmptyState(
                icon: Icons.rate_review_outlined,
                message: 'ยังไม่มีรีวิว',
              ),
            )
          else
            StreamBuilder<List<ReviewModel>>(
              stream: _reviewService.reviewsForUser(widget.revieweeId!),
              builder: (context, snapshot) {
                final reviews = snapshot.data ?? const [];
                if (reviews.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const EmptyState(
                      icon: Icons.rate_review_outlined,
                      message: 'ยังไม่มีรีวิว',
                    ),
                  );
                }
                return Column(
                  children: reviews
                      .map((r) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(
                                      5,
                                      (i) => Icon(
                                            i < r.rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 16,
                                            color: AppColors.star,
                                          )),
                                ),
                                if (r.comment.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(r.comment),
                                ],
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
