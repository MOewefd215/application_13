import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/upload_service.dart';

class VerificationScreen extends StatefulWidget {
  /// Pass the signed-in user's uid, e.g.
  /// `VerificationScreen(userId: FirebaseAuth.instance.currentUser!.uid)`.
  final String userId;
  const VerificationScreen({super.key, this.userId = 'demo_user'});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _uploadService = UploadService(); // ใส่ cloudName/uploadPreset จริงตรงนี้

  String? _studentCardUrl;
  String? _nationalIdUrl;
  bool _uploadingStudentCard = false;
  bool _uploadingNationalId = false;

  Future<void> _uploadDoc({
    required String fieldName,
    required void Function(bool) setLoading,
    required void Function(String) onSuccess,
  }) async {
    setLoading(true);
    try {
      final url = await _uploadService.pickAndUploadImage();
      if (url == null) return; // ผู้ใช้กดยกเลิก

      // บันทึกลิงก์รูปลง Firestore ที่ตาราง STUDENT (3.3 ตารางที่ 3.3)
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.userId)
          .set({fieldName: url}, SetOptions(merge: true));

      onSuccess(url);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('อัปโหลดสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('อัปโหลดไม่สำเร็จ: $e')));
      }
    } finally {
      setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allVerified = _studentCardUrl != null && _nationalIdUrl != null;

    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันตัวตน')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _docTile(
            icon: Icons.badge_outlined,
            title: 'บัตรนักศึกษา',
            uploadedUrl: _studentCardUrl,
            loading: _uploadingStudentCard,
            onUpload: () => _uploadDoc(
              fieldName: 'std_card_url',
              setLoading: (v) => setState(() => _uploadingStudentCard = v),
              onSuccess: (url) => setState(() => _studentCardUrl = url),
            ),
          ),
          _docTile(
            icon: Icons.credit_card_outlined,
            title: 'บัตรประชาชน',
            uploadedUrl: _nationalIdUrl,
            loading: _uploadingNationalId,
            onUpload: () => _uploadDoc(
              fieldName: 'national_id_url',
              setLoading: (v) => setState(() => _uploadingNationalId = v),
              onSuccess: (url) => setState(() => _nationalIdUrl = url),
            ),
          ),
          _docTile(
            icon: Icons.email_outlined,
            title: 'ยืนยันอีเมล',
            uploadedUrl: null,
            loading: false,
            onUpload: () {},
            statusOverride: 'ยังไม่ได้ยืนยัน',
          ),
          _docTile(
            icon: Icons.phone_iphone_outlined,
            title: 'ยืนยันเบอร์โทรศัพท์',
            uploadedUrl: null,
            loading: false,
            onUpload: () {},
            statusOverride: 'ยังไม่ได้ยืนยัน',
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text('สถานะการยืนยัน',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  allVerified ? 'ยืนยันตัวตนแล้วบางส่วน' : 'ยังไม่ได้ยืนยันตัวตน',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docTile({
    required IconData icon,
    required String title,
    required String? uploadedUrl,
    required bool loading,
    required VoidCallback onUpload,
    String? statusOverride,
  }) {
    final status = statusOverride ??
        (uploadedUrl != null ? 'อัปโหลดแล้ว' : 'ยังไม่ได้อัปโหลด');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(status,
                    style: TextStyle(
                        fontSize: 12,
                        color: uploadedUrl != null
                            ? AppColors.success
                            : AppColors.textSecondary)),
              ],
            ),
          ),
          if (statusOverride == null)
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : OutlinedButton(
                    style:
                        OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: onUpload,
                    child: Text(
                      uploadedUrl != null ? 'อัปโหลดใหม่' : 'อัปโหลด',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
        ],
      ),
    );
  }
}
