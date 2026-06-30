// lib/models/app_user.dart
// 6-tier role system. Fully backward-compatible with prior 4-role enum.


enum UserRole {
  guest,          // unauthenticated / restricted
  student,        // enrolled student
  lecturer,       // course instructor (replaces "teacher")
  departmentAdmin,// dept-level management
  schoolAdmin,    // institution-wide admin
  superAdmin,     // platform owner
}

enum AccountType  { independent, linked, guest }
enum AccountStatus{ active, suspended, assigned, unassigned }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final UserRole role;
  final String roleName;
  final AccountType accountType;
  final AccountStatus status;
  final String? schoolId;
  final String? departmentId;
  final String classLevel;
  final String? subject;
  final List<String> courseIds;   // courses enrolled / taught
  final bool isFirstLogin;
  final bool adminAccessRevoked;
  final bool isPremium;

  const AppUser({
    required this.id,
    required this.name,
    this.email = '',
    this.photoUrl,
    this.role = UserRole.student,
    this.roleName = '',
    this.accountType = AccountType.independent,
    this.status = AccountStatus.active,
    this.schoolId,
    this.departmentId,
    this.classLevel = '',
    this.subject,
    this.courseIds = const [],
    this.isFirstLogin = false,
    this.adminAccessRevoked = false,
    this.isPremium = false,
  });

  // ── Identity helpers ───────────────────────────────────────────────────────
  String get uid => id;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get roleLabel {
    if (roleName.isNotEmpty) return roleName;
    switch (role) {
      case UserRole.guest:           return 'Guest';
      case UserRole.student:         return 'Student';
      case UserRole.lecturer:        return 'Lecturer';
      case UserRole.departmentAdmin: return 'Department Admin';
      case UserRole.schoolAdmin:     return 'School Admin';
      case UserRole.superAdmin:      return 'Super Admin';
    }
  }

  String get accountTypeLabel {
    switch (accountType) {
      case AccountType.independent: return 'Independent';
      case AccountType.linked:      return 'School-Linked';
      case AccountType.guest:       return 'Guest';
    }
  }

  // ── Role booleans ──────────────────────────────────────────────────────────
  bool get isGuest          => role == UserRole.guest || id.isEmpty;
  bool get isStudent        => role == UserRole.student;
  bool get isLecturer       => role == UserRole.lecturer;
  bool get isDeptAdmin      => role == UserRole.departmentAdmin;
  bool get isSchoolAdmin    => role == UserRole.schoolAdmin;
  bool get isSuperAdmin     => role == UserRole.superAdmin;

  // Backward-compat aliases used by existing code
  bool get isTeacher => isLecturer;
  bool get isAdmin   => isDeptAdmin || isSchoolAdmin || isSuperAdmin;
  bool get isParent  => false; // removed from hierarchy; safe fallback

  // ── Privilege system ───────────────────────────────────────────────────────
  int get privilegeLevel {
    switch (role) {
      case UserRole.guest:           return 0;
      case UserRole.student:         return 1;
      case UserRole.lecturer:        return 2;
      case UserRole.departmentAdmin: return 3;
      case UserRole.schoolAdmin:     return 4;
      case UserRole.superAdmin:      return 5;
    }
  }

  static int _level(UserRole r) {
    const m = {
      UserRole.guest: 0, UserRole.student: 1, UserRole.lecturer: 2,
      UserRole.departmentAdmin: 3, UserRole.schoolAdmin: 4, UserRole.superAdmin: 5,
    };
    return m[r] ?? 0;
  }

  bool hasMinRole(UserRole min) => privilegeLevel >= _level(min);

  // ── Permission gates ───────────────────────────────────────────────────────
  bool get canUploadContent    => hasMinRole(UserRole.lecturer);
  bool get canPostAnnouncement => hasMinRole(UserRole.lecturer);
  bool get canManageUsers      => hasMinRole(UserRole.departmentAdmin);
  bool get canManageSchool     => hasMinRole(UserRole.schoolAdmin);
  bool get canManagePlatform   => isSuperAdmin;

  // ── Firestore ──────────────────────────────────────────────────────────────
  factory AppUser.fromFirestore(String id, Map<String, dynamic> d) => AppUser(
    id: id,
    name: d['name'] ?? '',
    email: d['email'] ?? '',
    photoUrl: d['photoUrl'],
    role: _parseRole(d['role']),
    roleName: d['roleName'] ?? '',
    accountType: AccountType.values.firstWhere(
        (a) => a.name == d['accountType'], orElse: () => AccountType.independent),
    status: AccountStatus.values.firstWhere(
        (s) => s.name == d['status'], orElse: () => AccountStatus.active),
    schoolId: d['schoolId'],
    departmentId: d['departmentId'],
    classLevel: d['classLevel'] ?? '',
    subject: d['subject'],
    courseIds: List<String>.from(d['courseIds'] ?? []),
    isFirstLogin: d['isFirstLogin'] ?? false,
    adminAccessRevoked: d['adminAccessRevoked'] ?? false,
    isPremium: d['isPremium'] ?? false,
  );

  /// Handles both old 4-role values and new 6-role values stored in Firestore.
  static UserRole _parseRole(dynamic raw) {
    final s = raw?.toString() ?? '';
    // old values → new mapping
    if (s == 'teacher') return UserRole.lecturer;
    if (s == 'admin')   return UserRole.schoolAdmin;
    if (s == 'parent')  return UserRole.guest;
    return UserRole.values.firstWhere((r) => r.name == s,
        orElse: () => UserRole.student);
  }

  Map<String, dynamic> toFirestore() => {
    'name': name, 'email': email, 'photoUrl': photoUrl,
    'role': role.name, 'roleName': roleName,
    'accountType': accountType.name, 'status': status.name,
    'schoolId': schoolId, 'departmentId': departmentId,
    'classLevel': classLevel, 'subject': subject,
    'courseIds': courseIds,
    'isFirstLogin': isFirstLogin,
    'adminAccessRevoked': adminAccessRevoked,
    'isPremium': isPremium,
  };

  AppUser copyWith({
    String? id, String? name, String? email, String? photoUrl,
    UserRole? role, String? roleName,
    AccountType? accountType, AccountStatus? status,
    String? schoolId, String? departmentId,
    String? classLevel, String? subject, List<String>? courseIds,
    bool? isFirstLogin, bool? adminAccessRevoked, bool? isPremium,
  }) => AppUser(
    id: id ?? this.id, name: name ?? this.name,
    email: email ?? this.email, photoUrl: photoUrl ?? this.photoUrl,
    role: role ?? this.role, roleName: roleName ?? this.roleName,
    accountType: accountType ?? this.accountType,
    status: status ?? this.status,
    schoolId: schoolId ?? this.schoolId,
    departmentId: departmentId ?? this.departmentId,
    classLevel: classLevel ?? this.classLevel,
    subject: subject ?? this.subject,
    courseIds: courseIds ?? this.courseIds,
    isFirstLogin: isFirstLogin ?? this.isFirstLogin,
    adminAccessRevoked: adminAccessRevoked ?? this.adminAccessRevoked,
    isPremium: isPremium ?? this.isPremium,
  );
}
