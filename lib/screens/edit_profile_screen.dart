import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_user_model.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.user.fullName);
  late final TextEditingController _phoneController =
      TextEditingController(text: widget.user.phone ?? '');
  late final TextEditingController _extraController =
      TextEditingController(text: widget.user.universityOrAddress ?? '');
  bool _saving = false;

  bool get _isEmployer => widget.user.role == UserRole.employer;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อ-นามสกุล')));
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService().updateProfile(
        role: widget.user.role,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        universityOrAddress: _extraController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขโปรไฟล์')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label('ชื่อ-นามสกุล'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'กรอกชื่อ-นามสกุล'),
          ),
          const SizedBox(height: 16),
          _label('เบอร์โทรศัพท์'),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'กรอกเบอร์โทรศัพท์'),
          ),
          const SizedBox(height: 16),
          _label(_isEmployer ? 'ที่อยู่' : 'มหาวิทยาลัย / ทักษะความสามารถ'),
          const SizedBox(height: 8),
          TextField(
            controller: _extraController,
            maxLines: _isEmployer ? 2 : 1,
            decoration: InputDecoration(
              hintText: _isEmployer
                  ? 'ระบุที่อยู่สำหรับระบุตำแหน่งเริ่มต้น'
                  : 'เช่น มหาวิทยาลัยเทคโนโลยีราชมงคลอีสาน',
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}
