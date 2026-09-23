import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_role.dart';
import '../models/app_user_model.dart';

/// Real auth, replacing the placeholder "เข้าสู่ระบบ" button that used
/// to just navigate to Home without checking anything.
///
/// On sign-up this also writes:
///   users/{uid}      — u_email, u_role, u_created_at   (ตารางที่ 3.1)
///   employers/{uid}  — emp_fullname                    (ตารางที่ 3.2)
///   students/{uid}   — std_fullname                    (ตารางที่ 3.3)
/// depending on the role picked on the register form, so the rest of
/// the app (JobDetail, Verification, Profile, etc.) has real rows to
/// read/write against instead of the 'demo_user' placeholder id.
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
    required String role, // UserRole.employer or UserRole.student
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    await _db.collection('users').doc(uid).set({
      'u_email': email,
      'u_role': role,
      'u_created_at': FieldValue.serverTimestamp(),
    });

    if (role == UserRole.employer) {
      await _db.collection('employers').doc(uid).set({
        'emp_id': uid,
        'emp_fullname': fullName,
      });
    } else {
      await _db.collection('students').doc(uid).set({
        'std_id': uid,
        'std_fullname': fullName,
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

  /// Used by the profile edit screen — writes back to whichever
  /// role collection (`employers` or `students`) the signed-in user
  /// belongs to.
  Future<void> updateProfile({
    required String role,
    required String fullName,
    String? phone,
    String? universityOrAddress,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    final isEmployer = role == UserRole.employer;
    final collection = isEmployer ? 'employers' : 'students';
    await _db.collection(collection).doc(uid).set({
      if (isEmployer) 'emp_fullname': fullName else 'std_fullname': fullName,
      if (isEmployer) 'emp_phone': phone else 'std_phone': phone,
      if (isEmployer)
        'emp_address': universityOrAddress
      else
        'std_skill': universityOrAddress,
    }, SetOptions(merge: true));
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
