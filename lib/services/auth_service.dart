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
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email', 'profile']);

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
  /// cancels the picker — a normal outcome, not an error.
  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
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

  /// Re-authenticates with the current password, then sets the new one.
  /// Throws with a user-facing message on wrong-password / weak-password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('You must be signed in with an email account to change your password.');
    }
    final cred = fb.EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    try {
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') throw Exception('Current password is incorrect.');
      if (e.code == 'weak-password') throw Exception('New password is too weak.');
      throw Exception(e.message ?? 'Failed to change password.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') throw Exception('No account found for that email.');
      throw Exception(e.message ?? 'Failed to send reset email.');
    }
  }

  Future<void> updateUser(AppUser user, Map<String, dynamic> fields) async {
    if (user.id.isEmpty) return;
    await _db.collection(AppConstants.colUsers).doc(user.id).update(fields);
  }

  static Future<void> markFirstLoginComplete(String userId) async =>
      FirebaseFirestore.instance.collection(AppConstants.colUsers)
          .doc(userId).update({'isFirstLogin': false});

  // ── Gamification (real, minimal) ───────────────────────────────────────
  // Called once per Home page load. Decides — from the user's OWN last
  // activity date — whether the streak continues, resets, or is a no-op
  // for today. Never fabricates a number; every value here traces back to
  // an actual recorded day of app use.

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The 7 date keys (Mon..Sun) for the calendar week containing [d].
  static List<String> _weekKeys(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return List.generate(7, (i) => _dateKey(monday.add(Duration(days: i))));
  }

  Future<void> recordDailyActivity(AppUser user) async {
    if (user.id.isEmpty) return; // guest — nothing to record
    final now = DateTime.now();
    final today = _dateKey(now);
    if (user.lastActiveDate == today) return; // already recorded today

    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final newStreak = (user.lastActiveDate == yesterday) ? user.streakDays + 1 : 1;

    final thisWeek = _weekKeys(now).toSet();
    final carriedOver = user.weekActivityDates.where(thisWeek.contains);
    final newWeekDates = {...carriedOver, today}.toList()..sort();

    await _db.collection(AppConstants.colUsers).doc(user.id).set({
      'lastActiveDate': today,
      'streakDays': newStreak,
      'weekActivityDates': newWeekDates,
    }, SetOptions(merge: true));
  }

  /// The only entry point for awarding XP — every call site should be a
  /// decided source (quiz answer, magazine read, daily challenge), never
  /// an arbitrary bonus.
  Future<void> addXp(String userId, int amount) async {
    if (userId.isEmpty || amount == 0) return;
    await _db.collection(AppConstants.colUsers).doc(userId).set({
      'xpTotal': FieldValue.increment(amount),
    }, SetOptions(merge: true));
  }

  /// Real, user-driven "Continue Reading" position — set by
  /// LibraryReaderPage whenever the person turns a page.
  Future<void> setContinueReading(
    String userId, {
    required String itemId,
    required String title,
    required int page,
    int? totalPages,
  }) async {
    if (userId.isEmpty) return;
    await _db.collection(AppConstants.colUsers).doc(userId).set({
      'continueReadingItemId': itemId,
      'continueReadingTitle': title,
      'continueReadingPage': page,
      'continueReadingTotalPages': totalPages,
    }, SetOptions(merge: true));
  }
}
