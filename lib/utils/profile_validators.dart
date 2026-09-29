/// Basic client-side validation shared by sign-up and profile editing.
class ProfileValidators {
  static const genders = <String>{
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  };

  static String? validateName(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'กรุณากรอกชื่อ-นามสกุล';
    if (name.length < 2 || name.length > 80) {
      return 'ชื่อควรมีความยาว 2–80 ตัวอักษร';
    }
    return null;
  }

  static String? validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'กรุณากรอกอีเมล';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    }
    return null;
  }

  static String normalizePhone(String value) =>
      value.trim().replaceAll(RegExp(r'[\s()-]'), '');

  static String? validatePhone(String value) {
    final phone = normalizePhone(value);
    if (phone.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
    if (!RegExp(r'^(?:0\d{8,9}|\+?[1-9]\d{7,14})$').hasMatch(phone)) {
      return 'กรุณากรอกเบอร์โทรศัพท์ 9–15 หลัก หรือรูปแบบ +รหัสประเทศ';
    }
    return null;
  }

  static String? validateAddress(String value) {
    final address = value.trim();
    if (address.isEmpty) return 'กรุณากรอกที่อยู่';
    if (address.length < 5 || address.length > 250) {
      return 'ที่อยู่ควรมีความยาว 5–250 ตัวอักษร';
    }
    return null;
  }

  static String? validateGender(String? value) {
    if (value == null || !genders.contains(value)) {
      return 'กรุณาเลือกเพศ';
    }
    return null;
  }

  static int? parseAge(String value) => int.tryParse(value.trim());

  static String? validateAge(String value) {
    final age = parseAge(value);
    if (age == null) return 'กรุณากรอกอายุเป็นตัวเลขจำนวนเต็ม';
    if (age < 13 || age > 100) return 'อายุต้องอยู่ระหว่าง 13–100 ปี';
    return null;
  }
}
