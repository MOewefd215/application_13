import 'package:flutter/material.dart';
import '../models/job_application_model.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';

class ApplicantProfileScreen extends StatelessWidget {
  final JobApplicationModel application;
  const ApplicantProfileScreen({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final profile = application.applicantProfile ?? const <String, dynamic>{};
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0;
    final name = profile['name'] as String? ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1);
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลนักศึกษาผู้สมัคร')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.border,
              child: Text(initial, style: const TextStyle(fontSize: 28))),
          const SizedBox(height: 12),
          Center(
              child: Text(profile['name'] as String? ?? 'นักศึกษา',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold))),
          Center(
            child: StreamBuilder<ReviewSummary>(
              stream: ReviewService().summaryForUser(application.studentId),
              builder: (context, snapshot) {
                final currentRating = snapshot.data?.average ?? rating;
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star, color: AppColors.star, size: 18),
                  Text(' ${currentRating.toStringAsFixed(1)}'),
                ]);
              },
            ),
          ),
          const SizedBox(height: 20),
          _row('อีเมล', profile['email']),
          _row('เบอร์โทร', profile['phone']),
          _row('มหาวิทยาลัย', profile['university']),
          _row('คณะ', profile['faculty']),
          _row('ชั้นปี', profile['year']),
          _row('ทักษะ', profile['skill']),
          const SizedBox(height: 20),
          const Text('รีวิวที่ได้รับ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: ReviewService().reviewsForUser(application.studentId),
            builder: (context, snapshot) {
              final reviews = snapshot.data ?? const [];
              if (reviews.isEmpty) return const Text('ยังไม่มีรีวิว');
              return Column(
                  children: reviews
                      .map((review) => Card(
                            child: ListTile(
                              leading:
                                  const Icon(Icons.star, color: AppColors.star),
                              title: Text('${review.rating} / 5'),
                              subtitle: Text(review.comment.isEmpty
                                  ? 'ไม่มีความคิดเห็น'
                                  : review.comment),
                            ),
                          ))
                      .toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _row(String title, Object? value) => Card(
        child: ListTile(title: Text(title), subtitle: Text('${value ?? '-'}')),
      );
}
