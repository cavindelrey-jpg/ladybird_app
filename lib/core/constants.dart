// lib/core/constants.dart
class AppConstants {
  AppConstants._();

  static const String appName    = 'CFPMI';
  static const String appVersion = '2.0.1';

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
  static const String colSerials         = 'serials';

  // Top-level collections
  static const String colAuditLogs       = 'audit_logs';
  static const String colSubscriptions   = 'subscriptions';
  static const String colAppConfig       = 'app_config';
  static const String colArticles        = 'articles';
  static const String colHeroSlides      = 'heroSlides';
  static const String colNotifications   = 'notifications';
  static const String colFollows         = 'follows';
  static const String colLikes           = 'likes';
  static const String colPublicCourses   = 'public_courses';
  static const String colRatings         = 'ratings';
  static const String colBookmarks       = 'bookmarks';
  static const String colLearners        = 'learners';
  static const String colFriendRequests  = 'friend_requests';
  static const String colFriendships     = 'friendships';
  static const String colConversations   = 'conversations';
  static const String colClubJoinRequests = 'club_join_requests';
  static const String colSaves           = 'saves';
  static const String colRecentViews     = 'recent_views';
  static const String colActivityDays    = 'activityDays';
  static const String colReadPositions   = 'readPositions';
  static const String colXpTransactions  = 'xpTransactions';
  static const String colUnlockedPapers  = 'unlockedPapers';
  static const String colPendingMagazineXp = 'pendingMagazineXp';
  static const String colTests           = 'tests';
  static const String colTestAttempts    = 'testAttempts';

  // Entitlements / physical sales (production_plan.md §9). Neither is
  // client-readable by ordinary users — see firestore.rules.
  static const String colPurchases       = 'purchases';
  static const String colVouchers        = 'vouchers';

  // Firebase Storage
  static const String storageContentFiles = 'content_files';
  static const String storageThumbnails   = 'thumbnails';
  static const String storageSubmissions  = 'submissions';
  static const String storageAvatars      = 'avatars';

  // SharedPreferences
  static const String prefInstitutionId  = 'institution_id';
  static const String prefSchoolCode     = 'school_code';
  static const String prefSerialNumber   = 'serial_number';
  static const String prefUserId         = 'user_id';
  static const String prefLanguage       = 'language';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefThemeMode      = 'theme_mode';
}
