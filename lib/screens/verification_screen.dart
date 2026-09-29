import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/upload_service.dart';
import '../theme/app_theme.dart';

class VerificationScreen extends StatefulWidget {
  final String? userId;
  const VerificationScreen({super.key, this.userId});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _upload = UploadService();
  final _phoneController = TextEditingController();
  Map<String, dynamic> _verification = {};
  bool _loading = false;
  bool _emailBusy = false;
  bool _phoneBusy = false;
  bool _phoneVerified = false;
  bool _isStudent = false;
  String? _error;
  String? _verificationId;

  String? get _uid => widget.userId ?? _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final uid = _uid;
    if (uid == null) return;
    final authUser = _auth.currentUser;
    await authUser?.reload();
    if (authUser?.emailVerified == true && authUser?.uid == uid) {
      await authUser!.getIdToken(true);
      await _db
          .collection('users')
          .doc(uid)
          .set({'u_email_verified': true}, SetOptions(merge: true));
    }
    final snapshot = await _db.collection('users').doc(uid).get();
    if (!mounted) return;
    setState(() {
      _verification = Map<String, dynamic>.from(
          snapshot.data()?['u_verification'] as Map? ?? {});
      _phoneController.text = snapshot.data()?['u_phone'] as String? ?? '';
      _phoneVerified = snapshot.data()?['u_phone_verified'] == true;
      _isStudent = snapshot.data()?['u_role'] == 'student';
    });
  }

  Future<void> _uploadStudentCard() async {
    final uid = _uid;
    if (uid == null || _auth.currentUser?.uid != uid) return;
    if (!_isStudent) {
      setState(
          () => _error = 'Only student accounts can submit a student card');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await _upload.pickAndUploadVerificationImage(
        userId: uid,
        documentType: 'student_card',
      );
      if (url == null) return;
      await _db.collection('users').doc(uid).set({
        'u_verification': {
          'student_card_url': url,
          'student_card_status': 'pending_review',
          'student_card_submitted_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      await _loadStatus();
    } catch (error) {
      if (mounted) setState(() => _error = 'อัปโหลดไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() {
      _emailBusy = true;
      _error = null;
    });
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งลิงก์ยืนยันไปที่อีเมลแล้ว')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'ส่งอีเมลไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _verifyPhone() async {
    final user = _auth.currentUser;
    final uid = _uid;
    final rawPhone = _phoneController.text.trim();
    final phone =
        rawPhone.startsWith('0') ? '+66${rawPhone.substring(1)}' : rawPhone;
    if (user == null || uid == null || phone.isEmpty) {
      setState(
          () => _error = 'กรอกเบอร์โทรศัพท์พร้อมรหัสประเทศ เช่น +66812345678');
      return;
    }
    setState(() {
      _phoneBusy = true;
      _error = null;
    });
    final result = Completer<String>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          try {
            await user.updatePhoneNumber(credential);
            if (!result.isCompleted) result.complete('verified');
          } catch (error) {
            if (!result.isCompleted) result.completeError(error);
          }
        },
        verificationFailed: (error) {
          if (!result.isCompleted) result.completeError(error);
        },
        codeSent: (verificationId, _) {
          _verificationId = verificationId;
          if (!result.isCompleted) result.complete('code_sent');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          if (!result.isCompleted) result.complete('code_sent');
        },
      );
      final state = await result.future.timeout(const Duration(minutes: 2));
      if (state == 'code_sent' && mounted) {
        final codeController = TextEditingController();
        final code = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ใส่รหัส OTP'),
            content: TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'รหัส 6 หลัก'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก')),
              FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, codeController.text.trim()),
                  child: const Text('ยืนยัน')),
            ],
          ),
        );
        codeController.dispose();
        if (code == null || _verificationId == null) return;
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        await user.updatePhoneNumber(credential);
      }
      await user.getIdToken(true);
      await _db.collection('users').doc(uid).set({
        'u_phone': user.phoneNumber ?? phone,
        'u_phone_verified': true,
      }, SetOptions(merge: true));
      await _loadStatus();
    } catch (error) {
      if (mounted) setState(() => _error = 'ยืนยันเบอร์ไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null || _uid == null || user.uid != _uid) {
      return Scaffold(
        appBar: AppBar(title: const Text('ยืนยันตัวตน')),
        body: const Center(
            child: Text('กรุณาเข้าสู่ระบบด้วยบัญชีเจ้าของโปรไฟล์')),
      );
    }
    final emailVerified = user.emailVerified;
    final cardStatus = _verification['student_card_status'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันตัวตน')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _statusCard('อีเมล', emailVerified ? 'ยืนยันแล้ว' : 'ยังไม่ยืนยัน',
              emailVerified),
          if (!emailVerified) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _emailBusy ? null : _sendEmailVerification,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: Text(_emailBusy ? 'กำลังส่ง...' : 'ส่งลิงก์ยืนยันอีเมล'),
            ),
            TextButton(
                onPressed: _loadStatus,
                child: const Text('ฉันกดยืนยันแล้ว · ตรวจสอบอีกครั้ง')),
          ],
          const SizedBox(height: 16),
          _statusCard('เบอร์โทรศัพท์',
              _phoneVerified ? 'ยืนยันแล้ว' : 'ยังไม่ยืนยัน', _phoneVerified),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'เบอร์พร้อมรหัสประเทศ', hintText: '+66812345678'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _phoneBusy ? null : _verifyPhone,
            icon: const Icon(Icons.sms_outlined),
            label:
                Text(_phoneBusy ? 'กำลังส่ง OTP...' : 'ส่ง OTP และยืนยันเบอร์'),
          ),
          const SizedBox(height: 16),
          _statusCard(
              'บัตรนักศึกษา',
              switch (cardStatus) {
                'pending_review' => 'รอตรวจสอบ',
                'approved' => 'ผ่านการตรวจสอบ',
                'rejected' => 'ไม่ผ่าน · อัปโหลดใหม่ได้',
                _ => 'ยังไม่ได้ส่ง',
              },
              cardStatus == 'approved'),
          const Text('ภาพบัตรจะถูกอัปโหลดไปยัง Cloudinary และส่งให้ตรวจสอบ'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _uploadStudentCard,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.badge_outlined),
            label: Text(_loading ? 'กำลังอัปโหลด...' : 'เลือกรูปบัตรนักศึกษา'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(String title, String status, bool verified) => Card(
        color: AppColors.card,
        child: ListTile(
          leading: Icon(verified ? Icons.verified : Icons.pending_outlined,
              color: verified ? AppColors.success : AppColors.textSecondary),
          title: Text(title),
          subtitle: Text(status),
        ),
      );
}
