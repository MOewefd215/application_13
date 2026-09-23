import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();

  bool isLoginTab = true;
  bool obscurePassword = true;
  bool loading = false;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole; // UserRole.employer or UserRole.student

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('กรุณากรอกอีเมลและรหัสผ่าน');
      return;
    }
    if (!isLoginTab) {
      if (_fullNameController.text.trim().isEmpty) {
        _showError('กรุณากรอกชื่อ-นามสกุล');
        return;
      }
      if (_selectedRole == null) {
        _showError('กรุณาเลือกประเภทผู้ใช้งาน');
        return;
      }
    }

    setState(() => loading = true);
    try {
      if (isLoginTab) {
        await _authService.signIn(email: email, password: password);
      } else {
        await _authService.signUp(
          fullName: _fullNameController.text.trim(),
          email: email,
          password: password,
          role: _selectedRole!,
        );
      }
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      _showError(_authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.school_outlined,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text('มือโปรวัยเรียน',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('หางานง่าย ได้งานแน่',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 28),

              // Tab toggle: เข้าสู่ระบบ / สมัครสมาชิก
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: _tabButton('เข้าสู่ระบบ', true)),
                    Expanded(child: _tabButton('สมัครสมาชิก', false)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ฟอร์มสมัครสมาชิก มีเฉพาะตอนเลือกแท็บ "สมัครสมาชิก"
              if (!isLoginTab) ...[
                _label('ชื่อ-นามสกุล'),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullNameController,
                  decoration:
                      const InputDecoration(hintText: 'กรอกชื่อ-นามสกุล'),
                ),
                const SizedBox(height: 16),
                _label('ประเภทผู้ใช้งาน'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _roleChip(
                        label: 'ผู้จ้างงาน',
                        icon: Icons.business_center_outlined,
                        role: UserRole.employer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _roleChip(
                        label: 'นักศึกษาผู้รับงาน',
                        icon: Icons.school_outlined,
                        role: UserRole.student,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              _label('อีเมล'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'กรอกอีเมล'),
              ),
              const SizedBox(height: 16),

              _label('รหัสผ่าน'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'กรอกรหัสผ่าน',
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              if (isLoginTab) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('ลืมรหัสผ่าน?'),
                  ),
                ),
              ] else
                const SizedBox(height: 16),

              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isLoginTab ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก'),
              ),
              const SizedBox(height: 20),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('หรือเข้าสู่ระบบด้วย',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('เข้าสู่ระบบด้วย Google'),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 16, color: AppColors.success),
                  SizedBox(width: 6),
                  Text('ปลอดภัย ยืนยันได้งานแน่นอน',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _emailController.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลืมรหัสผ่าน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('กรอกอีเมลที่ใช้สมัคร ระบบจะส่งลิงก์ตั้งรหัสผ่านใหม่ให้'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'กรอกอีเมล'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ส่งลิงก์'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        _showError('ส่งลิงก์ตั้งรหัสผ่านใหม่ไปที่ $email แล้ว กรุณาเช็คอีเมล');
      }
    } catch (e) {
      if (mounted) _showError(_authService.friendlyError(e));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => loading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      _showError(_authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _tabButton(String text, bool tabIsLogin) {
    final bool selected = isLoginTab == tabIsLogin;
    return GestureDetector(
      onTap: () => setState(() => isLoginTab = tabIsLogin),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button - 4),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _roleChip({
    required String label,
    required IconData icon,
    required String role,
  }) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : AppColors.textSecondary,
                size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      );
}
