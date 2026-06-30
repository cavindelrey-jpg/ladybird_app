// lib/core/constants.dart
class AppConstants {
  AppConstants._();

  static const String appName    = 'Academia';
  static const String appVersion = '2.0.0';

  // Firestore collections — schools subcollections
  static const String colUsers           = 'users';
  static const String colSchools         = 'schools';
  static const String colSeats           = 'seats';
  static const String colAnnounce        = 'announcements';
  static const String colLibrary         = 'library';
  static const String colAcademicContent = 'academic_content';
  static const String colClubs           = 'clubs';
  static const String colPosts           = 'posts';
  static const String colEvents          = 'events';
  static const String colMembers         = 'members';
  static const String colMarks           = 'marks';
  static const String colSequences       = 'sequences';
  static const String colSubjects        = 'subjects';
  static const String colTimetable       = 'timetable';
  static const String colChatrooms       = 'chatrooms';
  static const String colMessages        = 'messages';
  static const String colAttendance      = 'attendance';
  static const String colAssignments     = 'assignments';
  static const String colSubmissions     = 'submissions';
  static const String colCalendar        = 'academic_calendar';
  static const String colCourses         = 'courses';
  static const String colInstitutions    = 'institutions';

  // Top-level collections
  static const String colAuditLogs       = 'audit_logs';
  static const String colSubscriptions   = 'subscriptions';
  static const String colAppConfig       = 'app_config';

  // Firebase Storage
  static const String storageContentFiles = 'content_files';
  static const String storageThumbnails   = 'thumbnails';
  static const String storageSubmissions  = 'submissions';
  static const String storageAvatars      = 'avatars';

  // SharedPreferences
  static const String prefInstitutionId  = 'institution_id';
  static const String prefSchoolCode     = 'school_code';
  static const String prefUserId         = 'user_id';
  static const String prefLanguage       = 'language';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefThemeMode      = 'theme_mode';
}
