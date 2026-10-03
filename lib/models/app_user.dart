// lib/models/app_user.dart
// 6-tier role system. Fully backward-compatible with prior 4-role enum.

import '../config/branding.dart';
import 'entitlement.dart';
import 'school_voucher.dart' show SchoolRole, SchoolRoleX;
import 'teaching_assignment.dart';

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

extension UserRolePg on UserRole {
  /// The literal label Postgres's `user_role` enum expects — snake_case,
  /// unlike this enum's own camelCase `.name`. `_parseRole` below already
  /// handles reading either casing back in; this is for the (rare) write
  /// path that sets `public.users.role` directly rather than through a
  /// security-definer RPC (which already casts its own literals
  /// correctly server-side, e.g. `'school_admin'::user_role`).
  String get pgValue {
    switch (this) {
      case UserRole.departmentAdmin: return 'department_admin';
      case UserRole.schoolAdmin:     return 'school_admin';
      case UserRole.superAdmin:      return 'super_admin';
      case UserRole.guest:
      case UserRole.student:
      case UserRole.lecturer:        return name;
    }
  }
}

/// Editable education levels shown on Profile — Cameroon GCE-relevant,
/// plus generic options for independent/adult users.
class EducationLevels {
  EducationLevels._();
  static const List<String> all = [
    'Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5',
    'Lower Sixth Arts', 'Lower Sixth Science',
    'Upper Sixth Arts', 'Upper Sixth Science',
    'University', 'Professional / Working Adult',
    'Independent Learner', 'Other',
  ];
}

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
  final String _schoolName;

  /// Display name of the user's school. If empty, falls back to the active brand's app name when [isSchoolMember] is true.
  String get schoolName => _schoolName.isNotEmpty
      ? _schoolName
      : (isSchoolMember ? Branding.current.appName : '');

  /// The enrollment serial number this account was created with, if any.
  /// Kept for record-keeping / support (e.g. "which seat is this student
  /// occupying") — the claim itself is already permanently recorded on the
  /// SerialNumber doc, this is just a convenient back-reference on the user.
  final String? serialNumber;
  final String? departmentId;
  final String classLevel;
  final String? subject;
  final List<String> courseIds;   // courses enrolled / taught
  final bool isFirstLogin;
  final bool adminAccessRevoked;

  /// production_plan.md §8 — the account's access grant.
  ///
  /// This REPLACES the old flat `isPremium` bool as the source of truth.
  /// `isPremium` still exists below as a derived getter, so every existing
  /// caller (LibraryHomePage's premium-resource gate, XpRepository's
  /// unlock checks) keeps working unchanged — the flat bool was never the
  /// concept, just the cheapest possible encoding of it.
  final Entitlement entitlement;

  /// The raw pre-§8 `isPremium` field as stored on the document.
  ///
  /// Kept ONLY so accounts written before the entitlement model existed
  /// don't lose premium access. Read [isPremium] instead — never this.
  /// Once every user doc has been rewritten with entitlement fields (any
  /// profile save does it), this can be dropped.
  final bool legacyIsPremium;

  /// Free-text bio, ~100 words enforced at the Profile edit UI layer.
  final String bio;

  /// User-editable education level (Form 1 .. University .. Independent
  /// Learner). Free text, not tied to classLevel (which is school-scoped).
  final String educationLevel;

  /// Subjects the user has flagged as favorites in Profile settings —
  /// production_plan.md §5's personalization signal, feeds contextual
  /// recommendations (Library/Courses/Magazine/Quizzes surfacing
  /// favorite-subject content first). Values are drawn from
  /// kAcademicSubjects (see academic_content.dart) for consistency with
  /// every other subject picker in the app.
  final List<String> favoriteSubjects;

  /// Per-feature tap counts — kept for potential future usage-ranked
  /// surfaces; Quick Access itself is now a fixed set (see Home).
  final Map<String, int> quickAccessUsage;

  // ── Gamification (real, minimal — no fabricated numbers) ──────────────
  /// Total XP earned — only incremented through a decided XP source
  /// (quiz answers, magazine reads, daily challenge).
  final int xpTotal;

  /// Consecutive days the app has been opened. Recomputed by
  /// AuthService.recordDailyActivity() on each Home page load.
  final int streakDays;

  /// yyyy-MM-dd of the last recorded activity — decides whether today
  /// continues, resets, or is a no-op for the streak.
  final String? lastActiveDate;

  /// yyyy-MM-dd dates active THIS calendar week (Mon–Sun), trimmed weekly —
  /// drives the real M/T/W/T/F/S/S dots on Home.
  final List<String> weekActivityDates;

  // ── Continue Reading (real, minimal — see content_viewer_page.dart) ────
  final String? continueReadingItemId;
  final String? continueReadingTitle;
  final int continueReadingPage;
  final int? continueReadingTotalPages;

  // ── School membership (architecture brief items 2-6) ───────────────────
  /// This account's role WITHIN [schoolId], set only by redeeming a
  /// SchoolVoucher (see school_access_repository.dart) — never
  /// self-assigned. Null means "has a schoolId or not, but no school-app
  /// role" — the actual gate every school-only screen/nav entry checks,
  /// since holding an ordinary Academia account must never by itself grant
  /// access to a school's app (item 2).
  final SchoolRole? schoolRole;

  /// (subject, classLevel) pairs this teacher is actually assigned to —
  /// the real permission source for marks entry (item 22). Empty for
  /// every non-teacher role.
  final List<TeachingAssignment> teachingAssignments;

  /// The classLevel this account is Class Master of, if any (item 23).
  /// Independent of [teachingAssignments] — a class master's broader
  /// permission applies to this class regardless of which subject(s)
  /// they teach there.
  final String? classMasterOfClass;

  /// The school_vouchers/{code} doc that granted [schoolRole] — audit
  /// trail, and (same reasoning as Entitlement.sourceRef /
  /// isValidGiftRedemption() in firestore.rules) what lets the security
  /// rule verify a self-service schoolId/schoolRole write against the
  /// referenced voucher's own stored school/role rather than trusting the
  /// client's claim.
  final String? schoolVoucherRef;

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
    String schoolName = '',
    this.serialNumber,
    this.departmentId,
    this.classLevel = '',
    this.subject,
    this.courseIds = const [],
    this.isFirstLogin = false,
    this.adminAccessRevoked = false,
    this.entitlement = const Entitlement.free(),
    bool isPremium = false,
    this.bio = '',
    this.educationLevel = '',
    this.favoriteSubjects = const [],
    this.quickAccessUsage = const {},
    this.xpTotal = 0,
    this.streakDays = 0,
    this.lastActiveDate,
    this.weekActivityDates = const [],
    this.continueReadingItemId,
    this.continueReadingTitle,
    this.continueReadingPage = 1,
    this.continueReadingTotalPages,
    this.schoolRole,
    this.teachingAssignments = const [],
    this.classMasterOfClass,
    this.schoolVoucherRef,
  }) : _schoolName = schoolName,
       legacyIsPremium = isPremium;

  // ── Entitlement (production_plan.md §8) ────────────────────────────────────
  /// Whether this account currently has premium access, for ANY reason.
  ///
  /// Derived, not stored — this is the compatibility shim that let §8 land
  /// without touching the call sites that gate premium content
  /// (`academic_content_page.dart`, `xp_repository.dart`). Self-purchased, gifted,
  /// sponsored and admin-granted premium all read `true` here, which is
  /// correct: consumers of this getter care about ACCESS, not about which
  /// of §9's funding paths paid for it. Code that needs to distinguish
  /// them (e.g. the Profile membership row) reads [entitlement] directly.
  ///
  /// The `legacyIsPremium` arm covers accounts stored before the
  /// entitlement fields existed — see that field's doc comment.
  bool get isPremium => entitlement.isActive || legacyIsPremium;

  /// True only for §9's Gifted Premium — premium paid for by someone else.
  bool get isGiftedPremium =>
      entitlement.isActive && entitlement.source == EntitlementSource.gift;

  /// Premium Silver: every premium feature except Video Courses.
  bool get isSilver => entitlement.isSilver && entitlement.isActive;

  /// Premium Gold: full access, including Video Courses.
  bool get isGold => entitlement.isGold && entitlement.isActive;

  /// The single authoritative check for Video Course access — see
  /// core/feature_access.dart#AppFeature.coursesVideoLessons.
  bool get hasVideoCourseAccess => entitlement.includesVideoCourses;

  /// 'Free' / 'Premium' / 'Gifted Premium' — the three states §8 names.
  String get entitlementLabel =>
      entitlement.isActive || !legacyIsPremium ? entitlement.label : 'Premium';

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
  bool get isParent  => schoolRole == SchoolRole.parent;

  // ── School membership gates (architecture brief items 2, 22-24) ────────
  /// The actual "does this account belong to a school's app" check — NOT
  /// `!isGuest`. Every school-only screen/nav entry (School Connect,
  /// Timetable, Marks) must gate on this, not on merely being signed in.
  bool get isSchoolMember => schoolId != null && schoolId!.isNotEmpty && schoolRole != null;

  bool get isSchoolClassMaster => schoolRole == SchoolRole.classMaster || (classMasterOfClass ?? '').isNotEmpty;

  /// Marks/attendance-record permission for one (subject, classLevel) —
  /// item 22/23/24. Admins (schoolAdmin+) can record anywhere in their own
  /// school; a class master can record for their own class regardless of
  /// subject; any other teacher only for a (subject, classLevel) pair
  /// they're actually assigned to.
  bool canRecordMarksFor({required String subject, required String classLevel}) {
    if (isSuperAdmin) return true;
    if (isAdmin || hasMinRole(UserRole.schoolAdmin)) return true;
    if (isSchoolClassMaster && (classMasterOfClass == classLevel || classMasterOfClass == null || classMasterOfClass!.isEmpty)) return true;
    if (teachingAssignments.isEmpty) {
      // Default to allowing teachers/lecturers/school staff to record marks
      // when granular teaching assignments haven't been seeded yet.
      return isTeacher ||
          hasMinRole(UserRole.lecturer) ||
          (schoolRole != null && schoolRole != SchoolRole.student && schoolRole != SchoolRole.parent);
    }
    return teachingAssignments.contains(TeachingAssignment(subject: subject, classLevel: classLevel));
  }

  /// Whether this account can record marks for ANY (subject, classLevel).
  /// Available to super admins, admins, teachers, lecturers, class masters, and staff.
  bool get canRecordAnyMarks =>
      isSuperAdmin ||
      isAdmin ||
      isTeacher ||
      hasMinRole(UserRole.lecturer) ||
      isSchoolClassMaster ||
      (schoolRole != null && schoolRole != SchoolRole.student && schoolRole != SchoolRole.parent) ||
      teachingAssignments.isNotEmpty;

  /// Whether this account can create/manage homework for this specific
  /// (subject, classLevel) pair. Deliberately does NOT mirror
  /// canRecordMarksFor's class-master bypass: the homework RLS policy
  /// (supabase/migrations/20260903160000_homework_and_calendar_events.sql)
  /// only allows school_admin+ or a matching teachingAssignments entry --
  /// granting a class-master bypass here without a matching DB policy
  /// would show a working "Add Homework" button that silently fails on
  /// submit.
  bool canManageHomeworkFor({required String subject, required String classLevel}) {
    if (isSuperAdmin) return true;
    if (!isSchoolMember) return false;
    if (hasMinRole(UserRole.schoolAdmin)) return true;
    return teachingAssignments.contains(TeachingAssignment(subject: subject, classLevel: classLevel));
  }

  /// Whether this account can manage homework for ANY (subject, classLevel)
  /// at all -- the UI-visibility check for the Homework Management entry
  /// point, mirroring [canRecordAnyMarks]'s shape (minus the class-master
  /// bypass, for the same reason as [canManageHomeworkFor]).
  bool get canManageHomework =>
      isSuperAdmin || (isSchoolMember && (hasMinRole(UserRole.schoolAdmin) || teachingAssignments.isNotEmpty));

  /// Whether this account can manage timetables for their school.
  bool get canManageAnyTimetable =>
      isSuperAdmin || canManageSchool || (isSchoolMember && (schoolRole == SchoolRole.admin || schoolRole == SchoolRole.itSupport));

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
  /// Lightweight placeholder passed to pages that require a non-null
  /// AppUser (e.g. LibraryHomePage) when a guest is browsing read-only content.
  /// Never written to Firestore, never treated as a real account — id
  /// stays empty so any accidental write attempt is a visible no-op
  /// (AuthService methods already early-return on empty id).
  factory AppUser.guest() => const AppUser(id: '', name: 'Guest');

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
    schoolName: d['schoolName'] ?? d['school_name'] ?? '',
    serialNumber: d['serialNumber'],
    departmentId: d['departmentId'],
    classLevel: d['classLevel'] ?? '',
    subject: d['subject'],
    courseIds: List<String>.from(d['courseIds'] ?? []),
    isFirstLogin: d['isFirstLogin'] ?? false,
    adminAccessRevoked: d['adminAccessRevoked'] ?? false,
    isPremium: d['isPremium'] ?? false,
    entitlement: Entitlement.fromUserMap(d,
        legacyIsPremium: d['isPremium'] ?? false),
    bio: d['bio'] ?? '',
    educationLevel: d['educationLevel'] ?? '',
    favoriteSubjects: List<String>.from(d['favoriteSubjects'] ?? []),
    quickAccessUsage: Map<String, int>.from(d['quickAccessUsage'] ?? {}),
    xpTotal: (d['xpTotal'] as num?)?.toInt() ?? 0,
    streakDays: (d['streakDays'] as num?)?.toInt() ?? 0,
    lastActiveDate: d['lastActiveDate'],
    weekActivityDates: List<String>.from(d['weekActivityDates'] ?? []),
    continueReadingItemId: d['continueReadingItemId'],
    continueReadingTitle: d['continueReadingTitle'],
    continueReadingPage: (d['continueReadingPage'] as num?)?.toInt() ?? 1,
    continueReadingTotalPages: (d['continueReadingTotalPages'] as num?)?.toInt(),
    schoolRole: SchoolRoleX.fromName(d['schoolRole']?.toString() ?? ''),
    teachingAssignments: (d['teachingAssignments'] as List<dynamic>? ?? [])
        .map((m) => TeachingAssignment.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList(),
    classMasterOfClass: d['classMasterOfClass'],
    schoolVoucherRef: d['schoolVoucherRef'],
  );

  /// Handles both old 4-role values and new 6-role values stored in
  /// Firestore, PLUS Postgres's `user_role` enum labels (supabase/
  /// migrations/20260828060000_initial_schema.sql), which are snake_case
  /// ('school_admin', 'department_admin', 'super_admin') while this
  /// Dart enum's `.name` is camelCase ('schoolAdmin', etc.) — without
  /// these explicit cases, `firstWhere` never matches those three and
  /// silently falls through to student for EVERY account the
  /// redeem_school_voucher()/redeem_academia_voucher() RPCs correctly
  /// promoted server-side (e.g. an itSupport/"Super Admin" voucher
  /// redemption reads back as a plain student).
  static UserRole _parseRole(dynamic raw) {
    final s = raw?.toString() ?? '';
    // old values → new mapping
    if (s == 'teacher') return UserRole.lecturer;
    if (s == 'admin')   return UserRole.schoolAdmin;
    if (s == 'parent')  return UserRole.guest;
    // Postgres user_role enum (snake_case) → this Dart enum (camelCase)
    if (s == 'department_admin') return UserRole.departmentAdmin;
    if (s == 'school_admin')     return UserRole.schoolAdmin;
    if (s == 'super_admin')      return UserRole.superAdmin;
    return UserRole.values.firstWhere((r) => r.name == s,
        orElse: () => UserRole.student);
  }

  /// Supabase equivalent of fromFirestore — reads a row from `public.users`
  /// (see academia-cameroon's supabase/migrations — same shared table,
  /// plus 20260829360000_users_entitlement_school_columns.sql for the
  /// entitlement/school-membership columns this app adds on top).
  factory AppUser.fromSupabase(Map<String, dynamic> d) => AppUser(
    id: d['id'] as String,
    name: d['name'] ?? '',
    email: d['email'] ?? '',
    photoUrl: d['photo_url'],
    role: _parseRole(d['role']),
    roleName: d['role_name'] ?? '',
    accountType: AccountType.values.firstWhere(
        (a) => a.name == d['account_type'], orElse: () => AccountType.independent),
    status: AccountStatus.values.firstWhere(
        (s) => s.name == d['status'], orElse: () => AccountStatus.active),
    schoolId: d['institution_id'],
    schoolName: d['school_name'] ?? d['schoolName'] ?? '',
    serialNumber: d['serial_number'],
    departmentId: d['department_id'],
    classLevel: d['class_level'] ?? '',
    subject: d['subject'],
    courseIds: List<String>.from(d['course_ids'] ?? []),
    isFirstLogin: d['is_first_login'] ?? false,
    adminAccessRevoked: d['admin_access_revoked'] ?? false,
    isPremium: d['is_premium'] ?? false,
    entitlement: Entitlement(
      tier: EntitlementTier.values.firstWhere(
          (t) => t.name == d['entitlement_tier'], orElse: () => EntitlementTier.free),
      source: EntitlementSource.values.firstWhere(
          (s) => s.name == d['entitlement_source'], orElse: () => EntitlementSource.none),
      startAt: _dt(d['entitlement_start_at']),
      expiresAt: _dt(d['entitlement_expires_at']),
      sourceRef: d['entitlement_source_ref'],
    ),
    bio: d['bio'] ?? '',
    educationLevel: d['education_level'] ?? '',
    favoriteSubjects: List<String>.from(d['favorite_subjects'] ?? []),
    quickAccessUsage: Map<String, int>.from(d['quick_access_usage'] ?? {}),
    xpTotal: (d['xp_total'] as num?)?.toInt() ?? 0,
    streakDays: (d['streak_days'] as num?)?.toInt() ?? 0,
    lastActiveDate: d['last_active_date'],
    weekActivityDates: List<String>.from(d['week_activity_dates'] ?? []),
    continueReadingItemId: d['continue_reading_item_id'],
    continueReadingTitle: d['continue_reading_title'],
    continueReadingPage: (d['continue_reading_page'] as num?)?.toInt() ?? 1,
    continueReadingTotalPages: (d['continue_reading_total_pages'] as num?)?.toInt(),
    schoolRole: SchoolRoleX.fromName(d['school_role']?.toString() ?? ''),
    teachingAssignments: (d['teaching_assignments'] as List<dynamic>? ?? [])
        .map((m) => TeachingAssignment.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList(),
    classMasterOfClass: d['class_master_of_class'],
    schoolVoucherRef: d['school_voucher_ref'],
  );

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  /// Supabase equivalent of toFirestore — a partial row suitable for
  /// `.upsert()`/`.update()` against `public.users`. `id` is intentionally
  /// excluded (it's the auth.users FK, set once at signup, never rewritten).
  Map<String, dynamic> toSupabase() => {
    'name': name, 'email': email, 'photo_url': photoUrl,
    'role': role.name, 'role_name': roleName,
    'account_type': accountType.name, 'status': status.name,
    'institution_id': schoolId, 'school_name': _schoolName, 'serial_number': serialNumber, 'department_id': departmentId,
    'class_level': classLevel, 'subject': subject,
    'course_ids': courseIds,
    'is_first_login': isFirstLogin,
    'admin_access_revoked': adminAccessRevoked,
    // Written as the DERIVED value, so the legacy column stays a truthful
    // mirror of the entitlement for anything still reading it. The
    // entitlement_* columns below are the source of truth.
    'is_premium': isPremium,
    'entitlement_tier': entitlement.tier.name,
    'entitlement_source': entitlement.source.name,
    'entitlement_start_at': entitlement.startAt?.toIso8601String(),
    'entitlement_expires_at': entitlement.expiresAt?.toIso8601String(),
    'entitlement_source_ref': entitlement.sourceRef,
    'bio': bio,
    'education_level': educationLevel,
    'favorite_subjects': favoriteSubjects,
    'quick_access_usage': quickAccessUsage,
    'xp_total': xpTotal,
    'streak_days': streakDays,
    'last_active_date': lastActiveDate,
    'week_activity_dates': weekActivityDates,
    'continue_reading_item_id': continueReadingItemId,
    'continue_reading_title': continueReadingTitle,
    'continue_reading_page': continueReadingPage,
    'continue_reading_total_pages': continueReadingTotalPages,
    'school_role': schoolRole?.name,
    'teaching_assignments': teachingAssignments.map((t) => t.toMap()).toList(),
    'class_master_of_class': classMasterOfClass,
    'school_voucher_ref': schoolVoucherRef,
  };

  Map<String, dynamic> toFirestore() => {
    'name': name, 'email': email, 'photoUrl': photoUrl,
    'role': role.name, 'roleName': roleName,
    'accountType': accountType.name, 'status': status.name,
    'schoolId': schoolId, 'schoolName': _schoolName, 'serialNumber': serialNumber, 'departmentId': departmentId,
    'classLevel': classLevel, 'subject': subject,
    'courseIds': courseIds,
    'isFirstLogin': isFirstLogin,
    'adminAccessRevoked': adminAccessRevoked,
    // Written as the DERIVED value, so the legacy field stays a truthful
    // mirror of the entitlement for anything still reading it (older app
    // builds in the wild, the firestore.rules premium checks, exports).
    // The entitlement fields below are the source of truth.
    'isPremium': isPremium,
    ...entitlement.toUserMap(),
    'bio': bio,
    'educationLevel': educationLevel,
    'favoriteSubjects': favoriteSubjects,
    'quickAccessUsage': quickAccessUsage,
    'xpTotal': xpTotal,
    'streakDays': streakDays,
    'lastActiveDate': lastActiveDate,
    'weekActivityDates': weekActivityDates,
    'continueReadingItemId': continueReadingItemId,
    'continueReadingTitle': continueReadingTitle,
    'continueReadingPage': continueReadingPage,
    'continueReadingTotalPages': continueReadingTotalPages,
    'schoolRole': schoolRole?.name,
    'teachingAssignments': teachingAssignments.map((t) => t.toMap()).toList(),
    'classMasterOfClass': classMasterOfClass,
    'schoolVoucherRef': schoolVoucherRef,
  };

  AppUser copyWith({
    String? id, String? name, String? email, String? photoUrl,
    UserRole? role, String? roleName,
    AccountType? accountType, AccountStatus? status,
    String? schoolId, String? schoolName, String? serialNumber, String? departmentId,
    String? classLevel, String? subject, List<String>? courseIds,
    bool? isFirstLogin, bool? adminAccessRevoked, bool? isPremium,
    Entitlement? entitlement,
    String? bio, String? educationLevel, List<String>? favoriteSubjects,
    Map<String, int>? quickAccessUsage,
    int? xpTotal, int? streakDays, String? lastActiveDate,
    List<String>? weekActivityDates,
    String? continueReadingItemId, String? continueReadingTitle,
    int? continueReadingPage, int? continueReadingTotalPages,
    SchoolRole? schoolRole, List<TeachingAssignment>? teachingAssignments,
    String? classMasterOfClass, String? schoolVoucherRef,
  }) => AppUser(
    id: id ?? this.id, name: name ?? this.name,
    email: email ?? this.email, photoUrl: photoUrl ?? this.photoUrl,
    role: role ?? this.role, roleName: roleName ?? this.roleName,
    accountType: accountType ?? this.accountType,
    status: status ?? this.status,
    schoolId: schoolId ?? this.schoolId,
    schoolName: schoolName ?? this._schoolName,
    serialNumber: serialNumber ?? this.serialNumber,
    departmentId: departmentId ?? this.departmentId,
    classLevel: classLevel ?? this.classLevel,
    subject: subject ?? this.subject,
    courseIds: courseIds ?? this.courseIds,
    isFirstLogin: isFirstLogin ?? this.isFirstLogin,
    adminAccessRevoked: adminAccessRevoked ?? this.adminAccessRevoked,
    isPremium: isPremium ?? legacyIsPremium,
    entitlement: entitlement ?? this.entitlement,
    bio: bio ?? this.bio,
    educationLevel: educationLevel ?? this.educationLevel,
    favoriteSubjects: favoriteSubjects ?? this.favoriteSubjects,
    quickAccessUsage: quickAccessUsage ?? this.quickAccessUsage,
    xpTotal: xpTotal ?? this.xpTotal,
    streakDays: streakDays ?? this.streakDays,
    lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    weekActivityDates: weekActivityDates ?? this.weekActivityDates,
    continueReadingItemId: continueReadingItemId ?? this.continueReadingItemId,
    continueReadingTitle: continueReadingTitle ?? this.continueReadingTitle,
    continueReadingPage: continueReadingPage ?? this.continueReadingPage,
    continueReadingTotalPages: continueReadingTotalPages ?? this.continueReadingTotalPages,
    schoolRole: schoolRole ?? this.schoolRole,
    teachingAssignments: teachingAssignments ?? this.teachingAssignments,
    classMasterOfClass: classMasterOfClass ?? this.classMasterOfClass,
    schoolVoucherRef: schoolVoucherRef ?? this.schoolVoucherRef,
  );
}
