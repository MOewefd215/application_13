import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/location_service.dart';
import '../models/user_role.dart';
import '../models/job_model.dart';
import 'job_detail_screen.dart';
import 'notification_screen.dart';
import 'job_history_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'post_job_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int navIndex = 0;
  bool _loadingRole = true;
  bool _isEmployer = false; // ตาม role 3.1.1 ผู้จ้างงาน / 3.1.2 นักศึกษา
  final _jobService = JobService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategory; // null = ทั้งหมด
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadMyLocation();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final role = await AuthService().getUserRole();
    if (mounted) {
      setState(() {
        _isEmployer = role == UserRole.employer;
        _loadingRole = false;
      });
    }
  }

  Future<void> _loadMyLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _myLat = pos.latitude;
          _myLng = pos.longitude;
        });
      }
    } catch (_) {
      // ไม่ได้รับอนุญาต/ปิด GPS — ข้ามไป การ์ดจะไม่โชว์ระยะทางเฉยๆ
    }
  }

  void _onNavTap(int index) {
    if (index == navIndex) return;
    switch (index) {
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const JobHistoryScreen()));
        return;
      case 2:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        return;
      case 3:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()));
        return;
      case 4:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()));
        return;
    }
    setState(() => navIndex = index);
  }

  List<JobModel> _applyFilters(List<JobModel> jobs) {
    return jobs.where((job) {
      final matchesSearch = _searchQuery.isEmpty ||
          job.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          job.jobDesc.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == null || job.jobCategory == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: (!_loadingRole && _isEmployer)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.navy,
              icon: const Icon(Icons.add),
              label: const Text('โพสต์งาน'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PostJobScreen())),
            )
          : null,
      bottomNavigationBar:
          StudentProBottomNav(currentIndex: navIndex, onTap: _onNavTap),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('สวัสดี', style: TextStyle(fontSize: 12)),
                      Text('ผู้ใช้งาน',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationScreen())),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ค้นหางานที่ต้องการ...',
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('งานใกล้คุณ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('รายได้ดี เริ่มต้นที่นี่!',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Categories — แตะเพื่อกรอง, แตะซ้ำเพื่อยกเลิกกรอง
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: jobCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final c = jobCategories[index];
                  final label = c['label'] as String;
                  final selected = _selectedCategory == label;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _selectedCategory = selected ? null : label),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.navy : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: selected
                                    ? AppColors.navy
                                    : AppColors.border),
                          ),
                          child: Icon(c['icon'] as IconData,
                              color:
                                  selected ? Colors.white : AppColors.navy),
                        ),
                        const SizedBox(height: 6),
                        Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: selected
                                    ? AppColors.navy
                                    : AppColors.textPrimary)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == null
                      ? 'งานแนะนำสำหรับคุณ'
                      : 'งาน: $_selectedCategory',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (_selectedCategory != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedCategory = null),
                    child: const Text('ล้างตัวกรอง'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // งานจริงจาก Firestore — กรองด้วยคำค้นหา/หมวดหมู่ฝั่ง client
            StreamBuilder<List<JobModel>>(
              stream: _jobService.streamOpenJobs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final jobs = _applyFilters(snapshot.data ?? const []);
                if (jobs.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: EmptyState(
                      icon: Icons.work_outline,
                      message: (_searchQuery.isNotEmpty ||
                              _selectedCategory != null)
                          ? 'ไม่พบงานที่ตรงกับตัวกรอง'
                          : 'ยังไม่มีประกาศงานในขณะนี้',
                    ),
                  );
                }
                return Column(
                  children: jobs
                      .map((job) => JobCard(
                            job: job,
                            distanceLabel: (_myLat != null &&
                                    _myLng != null &&
                                    job.jobLat != null &&
                                    job.jobLng != null)
                                ? _locationService.formatDistance(
                                    _locationService.distanceKm(
                                      lat1: _myLat!,
                                      lng1: _myLng!,
                                      lat2: job.jobLat!,
                                      lng2: job.jobLng!,
                                    ),
                                  )
                                : null,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the job feed — tapping opens the real job's detail.
class JobCard extends StatelessWidget {
  final JobModel job;
  final String? distanceLabel;
  const JobCard({super.key, required this.job, this.distanceLabel});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => JobDetailScreen(
                    jobId: job.jobId,
                    jobTitle: job.jobTitle,
                    jobLat: job.jobLat,
                    jobLng: job.jobLng,
                  ))),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                image: job.photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(job.photoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: job.photoUrl == null
                  ? const Icon(Icons.image_outlined,
                      color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.jobTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${job.jobBudget.toStringAsFixed(0)} บาท/ชั่วโมง',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  if (distanceLabel != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: AppColors.blue),
                        const SizedBox(width: 2),
                        Text('ห่างจากคุณ $distanceLabel',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.blue)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
