/// Matches `u_role` on the USERS table (ตารางที่ 3.1) and decides which
/// of the two flows (3.1.1 ผู้จ้างงาน / 3.1.2 นักศึกษาผู้รับงาน) a
/// signed-in user sees.
class UserRole {
  static const String employer = 'employer'; // ผู้จ้างงาน
  static const String student = 'student'; // นักศึกษาผู้รับงาน

  static String label(String role) {
    switch (role) {
      case employer:
        return 'ผู้จ้างงาน';
      case student:
        return 'นักศึกษาผู้รับงาน';
      default:
        return role;
    }
  }
}
