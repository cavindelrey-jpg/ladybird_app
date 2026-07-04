// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../core/constants.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db  = FirebaseFirestore.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;

  fb.User? get firebaseUser   => _auth.currentUser;
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> currentAppUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final doc = await _db.collection(AppConstants.colUsers).doc(u.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(u.uid, doc.data()!);
  }

  Stream<AppUser?> currentAppUserStream() {
    final u = _auth.currentUser;
    if (u == null) return Stream.value(null);
    return _db.collection(AppConstants.colUsers).doc(u.uid).snapshots().map(
            (doc) => doc.exists ? AppUser.fromFirestore(u.uid, doc.data()!) : null);
  }

  Future<AppUser?> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid  = cred.user!.uid;
    final doc  = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    final user = AppUser.fromFirestore(uid, doc.data()!);
    if (user.status == AccountStatus.suspended) {
      await _auth.signOut();
      throw Exception('This account has been suspended. Contact administration.');
    }
    return user;
  }

  Future<AppUser> signUpIndependent({
    required String email, required String password, required String name,
    UserRole role = UserRole.student,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid  = cred.user!.uid;
    final user = AppUser(
      id: uid, name: name, email: email,
      role: role, accountType: AccountType.independent, status: AccountStatus.active,
    );
    await _db.collection(AppConstants.colUsers).doc(uid).set(user.toFirestore());
    return user;
  }

  /// Runs the Google account picker and signs in. Returns null if the user
  /// cancels the picker — that's a normal outcome, not an error, so the
  /// caller should just stay on the current screen.
  Future<AppUser?> signInWithGoogle() async {
    await _google.initialize();
    final googleUser = await _google.authenticate();

    // FIXED: Removed 'await' as .authentication is now a normal synchronous getter
    final googleAuth = googleUser.authentication;

    // FIXED: Removed 'accessToken' as 'idToken' is all Firebase needs for auth here
    final credential = fb.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return signInWithGoogleCredential(credential);
  }

  Future<AppUser> signInWithGoogleCredential(fb.AuthCredential credential) async {
    final cred = await _auth.signInWithCredential(credential);
    final uid  = cred.user!.uid;
    final doc  = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (doc.exists) return AppUser.fromFirestore(uid, doc.data()!);
    final user = AppUser(
      id: uid, name: cred.user?.displayName ?? 'Student',
      email: cred.user?.email ?? '', photoUrl: cred.user?.photoURL,
      role: UserRole.student, accountType: AccountType.independent, status: AccountStatus.active,
    );
    await _db.collection(AppConstants.colUsers).doc(uid).set(user.toFirestore());
    return user;
  }

  Future<AppUser> claimLinkedSeat({
    required String schoolCode, required String seatId,
    required String tempPassword, required String newEmail,
    required String newPassword, required String studentName,
  }) async {
    final seatRef = _db.collection(AppConstants.colSchools).doc(schoolCode)
        .collection(AppConstants.colSeats).doc(seatId);
    final seatDoc = await seatRef.get();
    if (!seatDoc.exists) throw Exception('Seat not found.');
    final data = seatDoc.data()!;
    if (data['claimed'] == true) throw Exception('Account already activated.');
    if (data['tempPassword'] != tempPassword) throw Exception('Incorrect temporary password.');
    final cred = await _auth.createUserWithEmailAndPassword(email: newEmail, password: newPassword);
    final uid  = cred.user!.uid;
    final user = AppUser(
      id: uid, name: studentName, email: newEmail,
      role: UserRole.student, roleName: 'School Student',
      accountType: AccountType.linked, status: AccountStatus.active,
      schoolId: schoolCode, classLevel: data['classLevel'] ?? '',
      isFirstLogin: true, adminAccessRevoked: true,
    );
    await _db.collection(AppConstants.colUsers).doc(uid).set(user.toFirestore());
    await seatRef.update({'claimed': true, 'claimedByUid': uid, 'tempPassword': '••••••••'});
    return user;
  }

  // ── Admin operations ───────────────────────────────────────────────────────
  Future<void> changeUserRole(String userId, UserRole newRole) =>
      _db.collection(AppConstants.colUsers).doc(userId).update({'role': newRole.name});

  Future<void> suspendUser(String userId) =>
      _db.collection(AppConstants.colUsers).doc(userId)
          .update({'status': AccountStatus.suspended.name});

  Future<void> reactivateUser(String userId) =>
      _db.collection(AppConstants.colUsers).doc(userId)
          .update({'status': AccountStatus.active.name});

  Stream<List<AppUser>> watchSchoolUsers(String schoolId) =>
      _db.collection(AppConstants.colUsers)
          .where('schoolId', isEqualTo: schoolId)
          .snapshots()
          .map((s) => s.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList());

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  /// Increments a Quick Access tap count for the signed-in user. Fire-and-
  /// forget by design — never blocks navigation on the write.
  Future<void> recordQuickAccessTap(String userId, String featureId) {
    if (userId.isEmpty) return Future.value();
    return _db.collection(AppConstants.colUsers).doc(userId).set({
      'quickAccessUsage': {featureId: FieldValue.increment(1)},
    }, SetOptions(merge: true));
  }

  Future<void> updateUser(AppUser user, Map<String, dynamic> fields) async {
    if (user.id.isEmpty) return;
    await _db.collection(AppConstants.colUsers).doc(user.id).update(fields);
  }

  static Future<void> markFirstLoginComplete(String userId) async =>
      FirebaseFirestore.instance.collection(AppConstants.colUsers)
          .doc(userId).update({'isFirstLogin': false});
}