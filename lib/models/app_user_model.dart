import 'user_role.dart';

/// Combines the private common profile in users/{uid} with the public
/// role profile in employers/{uid} or students/{uid}.
class AppUserModel {
  final String uid;
  final String email;
  final String role;
  final String fullName;
  final String? photoUrl;
  final String? phone;
  final String? address;
  final String? gender;
  final int? age;
  final String? universityOrAddress;
  final double rating;
  final int ratingCount;
  final String? university;
  final String? faculty;
  final String? year;

  const AppUserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.fullName,
    this.photoUrl,
    this.phone,
    this.address,
    this.gender,
    this.age,
    this.universityOrAddress,
    this.rating = 0,
    this.ratingCount = 0,
    this.university,
    this.faculty,
    this.year,
  });

  factory AppUserModel.fromMaps({
    required String uid,
    required Map<String, dynamic> userMap,
    Map<String, dynamic>? roleMap,
  }) {
    final role = userMap['u_role'] as String? ?? '';
    final isEmployer = role == UserRole.employer;
    final roleAddress = roleMap?[isEmployer ? 'emp_address' : 'std_address'];
    final legacyPhone = roleMap?[isEmployer ? 'emp_phone' : 'std_phone'];
    final rawAge =
        userMap['u_age'] ?? roleMap?[isEmployer ? 'emp_age' : 'std_age'];
    final age =
        rawAge is num ? rawAge.toInt() : int.tryParse(rawAge?.toString() ?? '');
    return AppUserModel(
      uid: uid,
      email: userMap['u_email'] as String? ?? '',
      role: role,
      fullName:
          roleMap?[isEmployer ? 'emp_fullname' : 'std_fullname'] as String? ??
              '',
      photoUrl:
          roleMap?[isEmployer ? 'emp_photo_url' : 'std_photo_url'] as String?,
      phone: userMap['u_phone'] as String? ?? legacyPhone as String?,
      address: userMap['u_address'] as String? ?? roleAddress as String?,
      gender: userMap['u_gender'] as String? ??
          roleMap?[isEmployer ? 'emp_gender' : 'std_gender'] as String?,
      age: age,
      universityOrAddress: isEmployer ? null : roleMap?['std_skill'] as String?,
      rating: (roleMap?['std_rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (roleMap?['std_review_count'] as num?)?.toInt() ?? 0,
      university: roleMap?['std_university'] as String?,
      faculty: roleMap?['std_faculty'] as String?,
      year: roleMap?['std_year']?.toString(),
    );
  }

  /// Shared fields stored once in users/{uid}; do not duplicate private
  /// contact details into public role documents.
  Map<String, dynamic> toUserMap() => {
        'u_email': email,
        'u_phone': phone,
        'u_address': address,
        'u_gender': gender,
        'u_age': age,
        'u_role': role,
      };
}
