import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../models/job_model.dart';
import '../services/upload_service.dart';
import '../services/job_service.dart';
import '../services/auth_service.dart';
import 'location_picker_screen.dart';

/// Shared category list — also used by HomeScreen's filter row so the
/// two stay in sync (same Thai labels used to store/query `job_category`).
const List<Map<String, dynamic>> jobCategories = [
  {'icon': Icons.menu_book_outlined, 'label': 'สอนพิเศษ'},
  {'icon': Icons.local_shipping_outlined, 'label': 'ขนของ'},
  {'icon': Icons.cleaning_services_outlined, 'label': 'ทำความสะอาด'},
  {'icon': Icons.brush_outlined, 'label': 'ออกแบบ'},
  {'icon': Icons.more_horiz, 'label': 'อื่นๆ'},
];

class PostJobScreen extends StatefulWidget {
  /// Pass an existing job to edit it instead of creating a new one.
  final JobModel? existingJob;
  const PostJobScreen({super.key, this.existingJob});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _locationController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  final _uploadService = UploadService();
  final _jobService = JobService();

  LatLng? _pickedLocation;
  String? _photoUrl;
  String? _category;
  bool _uploadingPhoto = false;
  bool _publishing = false;
  bool _deleting = false;

  bool get _isEditing => widget.existingJob != null;

  @override
  void initState() {
    super.initState();
    final job = widget.existingJob;
    if (job != null) {
      _titleController.text = job.jobTitle;
      _descController.text = job.jobDesc;
      _budgetController.text = job.jobBudget.toStringAsFixed(0);
      _dateController.text = job.jobDate ?? '';
      _timeController.text = job.jobTime ?? '';
      _category = job.jobCategory;
      _photoUrl = job.photoUrl;
      if (job.jobLat != null && job.jobLng != null) {
        _pickedLocation = LatLng(job.jobLat!, job.jobLng!);
        _locationController.text =
            '${job.jobLat!.toStringAsFixed(5)}, ${job.jobLng!.toStringAsFixed(5)}';
      }
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _pickedLocation?.latitude,
          initialLng: _pickedLocation?.longitude,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickedLocation = result;
        _locationController.text =
            '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year + 543}';
      });
    }
  }

  Future<void> _pickTime() async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'เลือกเวลาเริ่มงาน',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: start.replacing(hour: (start.hour + 2) % 24),
      helpText: 'เลือกเวลาสิ้นสุด',
    );
    if (end == null) return;
    setState(() {
      _timeController.text =
          '${start.format(context)} - ${end.format(context)}';
    });
  }

  Future<void> _pickPhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _uploadService.pickAndUploadImage();
      if (url != null) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _publish() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')));
      return;
    }
    final budget = double.tryParse(_budgetController.text.trim());
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกหัวข้องาน')));
      return;
    }
    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาระบุค่าจ้างให้ถูกต้อง')));
      return;
    }

    setState(() => _publishing = true);
    try {
      if (_isEditing) {
        await _jobService.updateJob(
          jobId: widget.existingJob!.jobId,
          jobTitle: _titleController.text,
          jobDesc: _descController.text,
          jobBudget: budget,
          jobLat: _pickedLocation?.latitude,
          jobLng: _pickedLocation?.longitude,
          photoUrl: _photoUrl,
          jobDate: _dateController.text.isEmpty ? null : _dateController.text,
          jobTime: _timeController.text.isEmpty ? null : _timeController.text,
          jobCategory: _category,
        );
      } else {
        await _jobService.postJob(
          empId: uid,
          jobTitle: _titleController.text,
          jobDesc: _descController.text,
          jobBudget: budget,
          jobLat: _pickedLocation?.latitude,
          jobLng: _pickedLocation?.longitude,
          photoUrl: _photoUrl,
          jobDate: _dateController.text.isEmpty ? null : _dateController.text,
          jobTime: _timeController.text.isEmpty ? null : _timeController.text,
          jobCategory: _category,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'บันทึกการแก้ไขสำเร็จ' : 'เผยแพร่งานสำเร็จ')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ทำรายการไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบประกาศงาน'),
        content: const Text('ต้องการลบประกาศงานนี้ใช่หรือไม่? ลบแล้วกู้คืนไม่ได้'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _jobService.deleteJob(widget.existingJob!.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ลบประกาศงานแล้ว')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'แก้ไขงาน' : 'โพสต์งาน'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _deleting ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _pickPhoto,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
                image: _photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: _photoUrl != null
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _uploadingPhoto
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.camera_alt_outlined,
                                color: AppColors.textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          _uploadingPhoto ? 'กำลังอัปโหลด...' : 'เพิ่มรูปภาพ',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          _label('ประเภทงาน'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: jobCategories
                .map((c) => DropdownMenuItem<String>(
                      value: c['label'] as String,
                      child: Text(c['label'] as String),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
            decoration: const InputDecoration(hintText: 'เลือกประเภทงาน'),
          ),
          const SizedBox(height: 16),
          _label('หัวข้องาน'),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'ระบุหัวข้องาน'),
          ),
          const SizedBox(height: 16),
          _label('รายละเอียดงาน'),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'อธิบายรายละเอียดของงาน'),
          ),
          const SizedBox(height: 16),
          _label('วันที่ทำงาน'),
          const SizedBox(height: 8),
          TextField(
            controller: _dateController,
            readOnly: true,
            onTap: _pickDate,
            decoration: InputDecoration(
              hintText: 'แตะเพื่อเลือกวันที่',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: _pickDate,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('เวลาทำงาน'),
          const SizedBox(height: 8),
          TextField(
            controller: _timeController,
            readOnly: true,
            onTap: _pickTime,
            decoration: InputDecoration(
              hintText: 'แตะเพื่อเลือกเวลา',
              suffixIcon: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: _pickTime,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('สถานที่'),
          const SizedBox(height: 8),
          TextField(
            controller: _locationController,
            readOnly: true,
            onTap: _pickLocation,
            decoration: InputDecoration(
              hintText: 'แตะเพื่อเลือกตำแหน่งบนแผนที่',
              suffixIcon: IconButton(
                icon: const Icon(Icons.location_on_outlined),
                onPressed: _pickLocation,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('ค่าจ้าง'),
          const SizedBox(height: 8),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'ระบุค่าจ้าง',
              suffixText: 'บาท/ชั่วโมง',
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEditing ? 'บันทึกการแก้ไข' : 'เผยแพร่งาน'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}
