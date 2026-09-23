import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/auth_service.dart';
import '../models/app_user_model.dart';
import '../models/user_role.dart';
import 'verification_screen.dart';
import 'report_problem_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import '../services/review_service.dart';
import '../models/review_model.dart';

enum VerificationOrWallet { verification, report }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  Future<AppUserModel?>? _userFuture;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    setState(() => _userFuture = _authService.getCurrentAppUser());
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _authService.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: StudentProBottomNav(currentIndex: 4, onTap: (_) {}),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('โปรไฟล์'),
      ),
      body: FutureBuilder<AppUserModel?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              message: 'ไม่พบข้อมูลผู้ใช้งาน กรุณาเข้าสู่ระบบใหม่',
            );
          }

          final isEmployer = user.role == UserRole.employer;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.border,
                    child: Icon(Icons.person,
                        size: 40, color: AppColors.textSecondary),
                  ),
                  Positioned(
                    right: 100,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditProfileScreen(user: user)),
                        );
                        if (updated == true) _loadUser();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  user.fullName.isEmpty ? '(ยังไม่ได้ตั้งชื่อ)' : user.fullName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              // Role badge — แยกให้เห็นชัดเจนระหว่างผู้จ้างงานกับนักศึกษา
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEmployer
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color:
                          isEmployer ? const Color(0xFFFB8C00) : AppColors.blue,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEmployer ? Icons.business_center : Icons.school,
                        size: 14,
                        color: isEmployer
                            ? const Color(0xFFFB8C00)
                            : AppColors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        UserRole.label(user.role),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isEmployer
                              ? const Color(0xFFFB8C00)
                              : AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isEmployer) ...[
                const SizedBox(height: 4),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, size: 16, color: AppColors.star),
                      const SizedBox(width: 4),
                      Text('${user.rating.toStringAsFixed(1)} (0 รีวิว)',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _card(
                title: 'ข้อมูลส่วนตัว',
                children: [
                  _infoRow('อีเมล', user.email.isEmpty ? '-' : user.email),
                  _infoRow(
                      'เบอร์โทร',
                      (user.phone == null || user.phone!.isEmpty)
                          ? '-'
                          : user.phone!),
                  _infoRow(
                    isEmployer ? 'ที่อยู่' : 'มหาวิทยาลัย / ทักษะ',
                    (user.universityOrAddress == null ||
                            user.universityOrAddress!.isEmpty)
                        ? '-'
                        : user.universityOrAddress!,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('รีวิวที่ได้รับ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              StreamBuilder<List<ReviewModel>>(
                stream: ReviewService().reviewsForUser(user.uid),
                builder: (context, snapshot) {
                  final reviews = snapshot.data ?? const [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
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
              const SizedBox(height: 16),
              if (!isEmployer)
                _menuTile(context, Icons.verified_user_outlined, 'ยืนยันตัวตน',
                    VerificationOrWallet.verification, user.uid),
              _menuTile(context, Icons.report_gmailerrorred_outlined,
                  'ร้องเรียน / แจ้งปัญหา', VerificationOrWallet.report, user.uid),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('ออกจากระบบ',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () => _confirmLogout(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
      );

  Widget _menuTile(BuildContext context, IconData icon, String label,
      VerificationOrWallet destination, String uid) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () {
        Widget page;
        switch (destination) {
          case VerificationOrWallet.verification:
            page = VerificationScreen(userId: uid);
            break;
          case VerificationOrWallet.report:
            page = const ReportProblemScreen();
            break;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}
