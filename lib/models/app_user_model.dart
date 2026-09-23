/// Merges `users/{uid}` with the role-specific doc
/// (`employers/{uid}` or `students/{uid}`) into one object the
/// Profile screen can render — this is what was missing before:
/// the profile UI never actually read back what was written at
/// sign-up.
class AppUserModel {
  final String uid;
  final String email;
  final String role; // UserRole.employer / UserRole.student
  final String fullName;
  final String? phone;
  final String? universityOrAddress; // std_skill/university for student, emp_address for employer
  final double rating;

  const AppUserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.fullName,
    this.phone,
    this.universityOrAddress,
    this.rating = 0,
  });

  factory AppUserModel.fromMaps({
    required String uid,
    required Map<String, dynamic> userMap,
    Map<String, dynamic>? roleMap,
  }) {
    final role = userMap['u_role'] as String? ?? '';
    final isEmployer = role == 'employer';
    return AppUserModel(
      uid: uid,
      email: userMap['u_email'] ?? '',
      role: role,
      fullName: roleMap?[isEmployer ? 'emp_fullname' : 'std_fullname'] ?? '',
      phone: roleMap?[isEmployer ? 'emp_phone' : 'std_phone'],
      universityOrAddress:
          roleMap?[isEmployer ? 'emp_address' : 'std_skill'],
      rating: (roleMap?['std_rating'] as num?)?.toDouble() ?? 0,
    );
  }
}
