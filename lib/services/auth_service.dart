import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_role.dart';
import '../models/app_user_model.dart';
import '../utils/profile_validators.dart';

/// Real auth, replacing the placeholder "เข้าสู่ระบบ" button that used
/// to just navigate to Home without checking anything.
///
/// On sign-up, shared identity/contact fields live under users/{uid}.
/// The employers/{uid} or students/{uid} document stores role-specific
/// public profile data. All three documents use the Firebase UID.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String fullName,
    required String email,
    required String password,
    required String role,
    required String phone,
    required String address,
    required String gender,
    required int age,
  }) async {
    final validationError = ProfileValidators.validateName(fullName) ??
        ProfileValidators.validateEmail(email) ??
        ProfileValidators.validatePhone(phone) ??
        ProfileValidators.validateAddress(address) ??
        ProfileValidators.validateGender(gender) ??
        ProfileValidators.validateAge(age.toString());
    if (validationError != null) throw ArgumentError(validationError);

    if (role != UserRole.employer && role != UserRole.student) {
      throw ArgumentError('ประเภทผู้ใช้งานไม่ถูกต้อง');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = ProfileValidators.normalizePhone(phone);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final uid = credential.user!.uid;

    final profile = AppUserModel(
      uid: uid,
      email: normalizedEmail,
      role: role,
      fullName: fullName.trim(),
      phone: normalizedPhone,
      address: address.trim(),
      gender: gender,
      age: age,
    );
    await _db.collection('users').doc(uid).set({
      ...profile.toUserMap(),
      'u_created_at': FieldValue.serverTimestamp(),
    });

    if (role == UserRole.employer) {
      await _db.collection('employers').doc(uid).set({
        'emp_id': uid,
        'emp_fullname': fullName.trim(),
      });
    } else {
      await _db.collection('students').doc(uid).set({
        'std_id': uid,
        'std_fullname': fullName.trim(),
      });
    }

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Real "หรือเข้าสู่ระบบด้วย Google" — was previously a dead button.
  /// First-time Google sign-in also creates the same `users/{uid}` +
  /// role doc as email sign-up would, defaulting to [UserRole.student]
  /// since Google doesn't ask for a role — the user can change it
  /// later from the profile edit screen.
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw StateError('ยกเลิกการเข้าสู่ระบบด้วย Google');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final uid = userCredential.user!.uid;

    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      await _db.collection('users').doc(uid).set({
        'u_email': userCredential.user!.email ?? '',
        'u_role': UserRole.student,
        'u_created_at': FieldValue.serverTimestamp(),
      });
      await _db.collection('students').doc(uid).set({
        'std_id': uid,
        'std_fullname': userCredential.user!.displayName ?? '',
      });
    }
    return userCredential;
  }

  /// Real "ลืมรหัสผ่าน?" — was previously a dead button.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Reads back everything the Profile screen needs — this was the
  /// missing piece that made sign-up data ("ชื่อจริง" etc.) never show
  /// up anywhere after registering.
  Future<AppUserModel?> getCurrentAppUser() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    final userSnap = await _db.collection('users').doc(uid).get();
    final userMap = userSnap.data();
    if (userMap == null) return null;

    final role = userMap['u_role'] as String?;
    final roleCollection = role == UserRole.employer ? 'employers' : 'students';
    final roleSnap = await _db.collection(roleCollection).doc(uid).get();

    return AppUserModel.fromMaps(
      uid: uid,
      userMap: userMap,
      roleMap: roleSnap.data(),
    );
  }

  Future<String?> getDisplayName(String uid) async {
    // Public role docs contain display names; common contact details stay
    // private in users/{uid}, which is readable only by its owner.
    final employer = await _db.collection('employers').doc(uid).get();
    final employerName = employer.data()?['emp_fullname'] as String?;
    if (employerName != null && employerName.trim().isNotEmpty) {
      return employerName.trim();
    }

    final student = await _db.collection('students').doc(uid).get();
    final studentName = student.data()?['std_fullname'] as String?;
    return studentName?.trim();
  }

  /// Used by the profile edit screen — writes back to whichever
  /// role collection (`employers` or `students`) the signed-in user
  /// belongs to.
  Future<void> updateProfile({
    required String role,
    required String fullName,
    required String phone,
    required String address,
    required String gender,
    required int age,
    String? universityOrAddress,
    String? photoUrl,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    final isEmployer = role == UserRole.employer;
    final roleCollection = isEmployer ? 'employers' : 'students';
    final roleData = <String, dynamic>{
      if (isEmployer) ...{
        'emp_phone': FieldValue.delete(),
        'emp_address': FieldValue.delete(),
        'emp_gender': FieldValue.delete(),
        'emp_age': FieldValue.delete(),
      } else ...{
        'std_phone': FieldValue.delete(),
        'std_address': FieldValue.delete(),
        'std_gender': FieldValue.delete(),
        'std_age': FieldValue.delete(),
      },
      if (isEmployer)
        'emp_fullname': fullName.trim()
      else
        'std_fullname': fullName.trim(),
      if (photoUrl != null)
        if (isEmployer)
          'emp_photo_url': photoUrl
        else
          'std_photo_url': photoUrl,
      if (!isEmployer && universityOrAddress != null)
        'std_skill': universityOrAddress.trim(),
    };

    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {
      'u_phone': phone.trim(),
      'u_address': address.trim(),
      'u_gender': gender,
      'u_age': age,
    });
    batch.set(_db.collection(roleCollection).doc(uid), roleData,
        SetOptions(merge: true));
    await batch.commit();
  }

  /// Reads back u_role for the given uid (defaults to current user).
  /// Used by HomeScreen to decide which flow (3.1.1 / 3.1.2) to show.
  Future<String?> getUserRole([String? uid]) async {
    final id = uid ?? currentUser?.uid;
    if (id == null) return null;
    final snap = await _db.collection('users').doc(id).get();
    return snap.data()?['u_role'] as String?;
  }

  /// Thai-friendly message for the common FirebaseAuthException codes,
  /// so the UI doesn't have to show raw English error strings.
  String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว';
        case 'invalid-email':
          return 'รูปแบบอีเมลไม่ถูกต้อง';
        case 'weak-password':
          return 'รหัสผ่านสั้นเกินไป (อย่างน้อย 6 ตัวอักษร)';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
        case 'too-many-requests':
          return 'ลองผิดหลายครั้งเกินไป กรุณาลองใหม่ภายหลัง';
        default:
          return 'เกิดข้อผิดพลาด: ${error.message ?? error.code}';
      }
    }
    return 'เกิดข้อผิดพลาด: $error';
  }
}
