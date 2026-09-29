import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_user_model.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/upload_service.dart';
import '../utils/profile_validators.dart';

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
  late final TextEditingController _addressController =
      TextEditingController(text: widget.user.address ?? '');
  late final TextEditingController _ageController =
      TextEditingController(text: widget.user.age?.toString() ?? '');
  late final TextEditingController _extraController =
      TextEditingController(text: widget.user.universityOrAddress ?? '');
  String? _selectedGender;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _photoUrl;
  final _uploadService = UploadService();

  bool get _isEmployer => widget.user.role == UserRole.employer;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.user.photoUrl;
    _selectedGender = widget.user.gender;
  }

  Future<void> _pickProfilePhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _uploadService.pickAndUploadImage();
      if (url != null && mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final validationError =
        ProfileValidators.validateName(_nameController.text) ??
            ProfileValidators.validatePhone(_phoneController.text) ??
            ProfileValidators.validateAddress(_addressController.text) ??
            ProfileValidators.validateGender(_selectedGender) ??
            ProfileValidators.validateAge(_ageController.text);
    if (validationError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService().updateProfile(
        role: widget.user.role,
        fullName: _nameController.text.trim(),
        phone: ProfileValidators.normalizePhone(_phoneController.text),
        address: _addressController.text.trim(),
        gender: _selectedGender!,
        age: ProfileValidators.parseAge(_ageController.text)!,
        universityOrAddress: _isEmployer ? null : _extraController.text.trim(),
        photoUrl: _photoUrl,
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
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.border,
                      backgroundImage:
                          _photoUrl == null ? null : NetworkImage(_photoUrl!),
                      child: _photoUrl == null
                          ? const Icon(Icons.person,
                              size: 48, color: AppColors.textSecondary)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _uploadingPhoto ? null : _pickProfilePhoto,
                          icon: _uploadingPhoto
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _uploadingPhoto ? null : _pickProfilePhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('เปลี่ยนรูปโปรไฟล์'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _label('ชื่อ-นามสกุล'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'กรอกชื่อ-นามสกุล'),
          ),
          const SizedBox(height: 16),
          _label('อีเมลบัญชี'),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              helperText: 'อีเมลใช้สำหรับเข้าสู่ระบบและแก้ไขไม่ได้ที่หน้านี้',
            ),
            child: Text(widget.user.email),
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
          _label('ที่อยู่'),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'กรอกที่อยู่'),
          ),
          const SizedBox(height: 16),
          _label('เพศ'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: const InputDecoration(hintText: 'เลือกเพศ'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('ชาย')),
              DropdownMenuItem(value: 'female', child: Text('หญิง')),
              DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
              DropdownMenuItem(
                value: 'prefer_not_to_say',
                child: Text('ไม่ประสงค์ระบุ'),
              ),
            ],
            onChanged: (value) => setState(() => _selectedGender = value),
          ),
          const SizedBox(height: 16),
          _label('อายุ'),
          const SizedBox(height: 8),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'อายุ (13–100 ปี)'),
          ),
          if (!_isEmployer) ...[
            const SizedBox(height: 16),
            _label('มหาวิทยาลัย / ทักษะความสามารถ'),
            const SizedBox(height: 8),
            TextField(
              controller: _extraController,
              decoration: const InputDecoration(
                hintText: 'เช่น มหาวิทยาลัย หรือทักษะที่ถนัด',
              ),
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: (_saving || _uploadingPhoto) ? null : _save,
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
