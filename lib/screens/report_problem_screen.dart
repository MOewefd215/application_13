import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/report_service.dart';
import '../services/upload_service.dart';
import '../services/auth_service.dart';

class ReportProblemScreen extends StatefulWidget {
  final String? jobId;
  const ReportProblemScreen({super.key, this.jobId});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _reportService = ReportService();
  final _uploadService = UploadService();
  final _descController = TextEditingController();

  String? _category;
  String? _evidenceUrl;
  bool _uploadingEvidence = false;
  bool _submitting = false;

  final _categories = const [
    'ผู้รับงานไม่มาตามนัด',
    'ผู้จ้างไม่ชำระเงิน',
    'ปัญหาการคืนเงิน',
    'พฤติกรรมไม่เหมาะสม',
    'อื่นๆ',
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    setState(() => _uploadingEvidence = true);
    try {
      final url = await _uploadService.pickAndUploadImage();
      if (url != null) setState(() => _evidenceUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('อัปโหลดไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<void> _submit() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')));
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกประเภทปัญหา')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await _reportService.submitReport(
        reporterId: uid,
        category: _category!,
        description: _descController.text,
        jobId: widget.jobId,
        evidenceUrl: _evidenceUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ส่งเรื่องร้องเรียนสำเร็จ')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ส่งไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ร้องเรียน / แจ้งปัญหา')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('ประเภทปัญหา',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
            decoration: const InputDecoration(hintText: 'เลือกประเภทปัญหา'),
          ),
          const SizedBox(height: 16),
          const Text('รายละเอียดปัญหา',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 5,
            decoration:
                const InputDecoration(hintText: 'อธิบายรายละเอียดของปัญหา'),
          ),
          const SizedBox(height: 16),
          const Text('แนบหลักฐาน (ถ้ามี)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _uploadingEvidence ? null : _pickEvidence,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
                image: _evidenceUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_evidenceUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: _evidenceUrl != null
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _uploadingEvidence
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.camera_alt_outlined,
                                color: AppColors.textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          _uploadingEvidence ? 'กำลังอัปโหลด...' : 'เพิ่มรูปภาพ',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('ส่งเรื่องร้องเรียน'),
          ),
        ],
      ),
    );
  }
}
