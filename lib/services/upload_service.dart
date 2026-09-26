import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Uploads images to Cloudinary (free tier, no credit card required) and
/// returns a public URL to store in the matching Firestore field —
/// e.g. `std_card_url` on the STUDENT table (3.3 ตารางที่ 3.3), or a
/// job's photo, or a user's avatar.
///
/// Setup (one-time, in Cloudinary dashboard):
///  1. Sign up free at https://cloudinary.com — no card needed.
///  2. Copy your "Cloud name" from the Dashboard.
///  3. Settings → Upload → Upload presets → Add upload preset →
///     Signing Mode = **Unsigned** → save, copy its name.
///  4. Fill in [cloudName] and [uploadPreset] below (or pass them in).
class UploadService {
  /// TODO: ใส่ค่าจาก Cloudinary Dashboard ของพี่ตรงนี้
  final String cloudName;
  final String uploadPreset;

  UploadService({
    this.cloudName = 'c65atebl',
    this.uploadPreset = 'studentpro_unsigned',
  });

  Uri get _uploadUrl =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// Opens the gallery, lets the user pick one image, uploads it, and
  /// returns the resulting HTTPS URL. Returns null if the user
  /// cancelled the picker.
  Future<String?> pickAndUploadImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 80,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;
    return uploadFile(File(picked.path));
  }

  /// Uploads an already-picked file and returns its public URL.
  /// Throws [StateError] with a Thai message on failure so the UI
  /// can show it directly in a SnackBar.
  Future<String> uploadFile(File file) async {
    if (cloudName == 'YOUR_CLOUD_NAME' ||
        uploadPreset == 'YOUR_UPLOAD_PRESET') {
      throw StateError(
          'ยังไม่ได้ตั้งค่า Cloudinary — ใส่ cloudName/uploadPreset ใน UploadService ก่อน');
    }

    final request = http.MultipartRequest('POST', _uploadUrl)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw StateError('อัปโหลดรูปไม่สำเร็จ (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null) {
      throw StateError('อัปโหลดสำเร็จแต่ไม่ได้รับลิงก์รูปกลับมา');
    }
    return url;
  }

  /// Uploads an audio recording to Cloudinary and returns its public URL.
  Future<String> uploadAudioFile(File file) async {
    final audioUrl = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
    );
    final request = http.MultipartRequest('POST', audioUrl)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw StateError(
        'Audio upload failed (' +
            response.statusCode.toString() +
            '): ' +
            response.body,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null) {
      throw StateError('Audio upload completed but no URL was returned.');
    }
    return url;
  }
}
