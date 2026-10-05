// lib/features/dashboard/universal_home_page.dart
//
// Personalized Academic Command Center for students.
//
// Re-architected according to senior UX/UI principles:
// 1. Personalized Context & Greeting: Time-of-day greeting, student identity, and academic session.
// 2. Academic Command Center Hero: Prioritizes the immediate next action ("what should I do now?"):
//    resumes active reading, prompts pending daily streak challenges, surfaces upcoming classes/tasks,
//    or kicks off exploration for new students.
// 3. Goal-Gradient Momentum Strip: Real, unfabricated progress metrics (daily streak, weekly study goal,
//    lifetime XP, passed quizzes, and school GPA average) with deep-link navigation.
// 4. Structured Academic Hubs: Progressive disclosure replacing equal-weight clutter:
//    - 4 Primary Hubs (Library, Past Questions, Quizzes, Courses)
//    - Secondary Tools (Dictionary, Groups, Daily Challenge Hub, Magazine, School Connect)
// 5. Schedule & Tasks: Real school timetable/personal study slots paired with live homework assignments.
// 6. Campus & Community Pulse: Live institutional announcements and upcoming club events.
// 7. Personalized Recommendations: Weighted subject recommendations via rankHomeSubjectsByUsage.
// 8. Academic Profile Summary Footer: Endowing ownership with student identity and entitlements.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/branding.dart';
import '../../models/academic_content.dart';
import '../../models/announcement.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../models/daily_learning.dart';
import '../../models/daily_learning_streak.dart';
import '../../models/homework.dart';
import '../../models/messaging.dart';
import '../../models/personal_study_slot.dart';
import '../../models/school_mark.dart';
import '../../models/school_timetable_slot.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import '../../pages/search_page.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/club_repository.dart';
import '../../repositories/daily_learning_repository.dart';
import '../../repositories/homework_repository.dart';
import '../../repositories/library_folder_repository.dart';
import '../../repositories/messaging_repository.dart';
import '../../repositories/personal_study_repository.dart';
import '../../repositories/school_marks_repository.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../repositories/test_repository.dart';
import '../../repositories/xp_repository.dart';
import '../../screens/command_center_screen.dart';
import '../../screens/dictionary_screen.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../academic_content/content_details_page.dart';
import '../academic_content/content_viewer_page.dart';
import '../academic_content/library_folder_page.dart';
import '../academic_content/library_home_page.dart';
import '../announcements/announcements_page.dart';
import '../clubs/clubs_page.dart';
import '../courses_marketplace/courses_home_page.dart';
import '../daily_learning/daily_learning_hub_page.dart';
import '../daily_learning/daily_learning_lesson_page.dart';
import '../magazine/magazine_feed_page.dart';
import '../messages/messages_home_page.dart';
import '../school/daily_notices/daily_notices_page.dart';
import '../school/exam_composer/exam_list_page.dart';
import '../school/homework_page.dart';
import '../school/marks_page.dart';
import '../school/school_connect_page.dart';
import '../school/timetable_page.dart';
import '../testing/quiz_categories_page.dart';
import '../testing/xp_dashboard_page.dart';
import '../timetable/personal_study_page.dart';

/// Card shadow used throughout this page — soft, physical elevation.
const List<BoxShadow> _glow = [
  BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 4)),
];

// ── Home's own "Recommended for You" ranking helpers ───────────────────
// Pure, top-level, unit-tested (test/home_recommendation_ranking_test.dart)
// — deliberately independent copies of the same shape of logic
// RecommendationRepository.rankSubjectsByUsage uses for contextual
// recommendations. Preserved exactly for test compatibility.

/// Reorders [favoriteSubjects] by descending completion count in [usage] --
/// the subject a student actually completes quizzes in most often outranks
/// one they only starred. Ties keep their ORIGINAL relative order via an
/// explicit index tie-break.
List<String> rankHomeSubjectsByUsage(
  List<String> favoriteSubjects,
  Map<String, int> usage,
) {
  final indexed = favoriteSubjects.asMap().entries.toList()
    ..sort((a, b) {
      final byUsage = (usage[b.value] ?? 0).compareTo(usage[a.value] ?? 0);
      if (byUsage != 0) return byUsage;
      return a.key.compareTo(b.key);
    });
  return indexed.map((e) => e.value).toList();
}

class UniversalHomePage extends StatefulWidget {
  final AppUser? user;
  const UniversalHomePage({super.key, this.user});

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  bool get _isGuest => widget.user == null;
  AppUser? get _u => widget.user;
  AppUser get _userOrGuest => _u ?? AppUser.guest();

  AppColors get ac => AppColors.of(context);



  // ── Cached Streams & Futures (Prevent infinite rebuild loops) ───────
  Stream<List<Conversation>>? _conversationsStream;
  Stream<DailyLearningStreak?>? _streakStream;
  Stream<(int, int)>? _xpStream;
  Future<Map<String, int>>? _completionCountsFuture;
  Future<({DailyLearningCourse course, DailyLearningLesson lesson, int completedCount, int totalCount})?>? _pendingDailyLessonFuture;
  Future<({double average, List<SchoolMark> subjects})?>? _latestMarksFuture;
  Stream<List<SchoolTimetableSlot>>? _timetableStream;
  Stream<List<PersonalStudySlot>>? _personalStudyStream;
  Stream<List<Homework>>? _homeworkStream;
  Stream<List<Announcement>>? _announcementsStream;
  Future<List<({String clubName, ClubEvent event})>>? _upcomingClubEventsFuture;

  void _initStreamsAndFutures() {
    final uid = _u?.id ?? '';
    final schoolId = _u?.schoolId;
    final classLevel = _u?.classLevel ?? '';

    if (_isGuest || uid.isEmpty) {
      _conversationsStream = const Stream.empty();
      _streakStream = const Stream.empty();
      _xpStream = const Stream.empty();
      _completionCountsFuture = Future.value(const {});
      _pendingDailyLessonFuture = Future.value(null);
      _latestMarksFuture = Future.value(null);
      _timetableStream = const Stream.empty();
      _personalStudyStream = const Stream.empty();
      _homeworkStream = const Stream.empty();
      _announcementsStream = const Stream.empty();
      _upcomingClubEventsFuture = Future.value(const []);
      return;
    }

    _conversationsStream = MessagingRepository.instance.watchConversations(uid);
    _streakStream = DailyLearningRepository.instance.watchStreak(uid);
    _xpStream = XpRepository.instance.watchBalance(uid);
    _completionCountsFuture = TestRepository.instance.subjectCompletionCountsOnce(uid);
    _pendingDailyLessonFuture = _getPendingDailyLesson();

    if (_u!.isSchoolMember) {
      _latestMarksFuture = _latestMarksSummary();
    } else {
      _latestMarksFuture = Future.value(null);
    }

    if (_u!.isSchoolMember && schoolId != null && schoolId.isNotEmpty && classLevel.isNotEmpty) {
      _timetableStream = SchoolTimetableRepository.instance.watchTodayForClass(schoolId, classLevel);
      _homeworkStream = HomeworkRepository.instance.watchForClass(schoolId, classLevel);
    } else {
      _timetableStream = const Stream.empty();
      _homeworkStream = const Stream.empty();
    }

    _personalStudyStream = PersonalStudyRepository.instance.watchToday(uid);
    _announcementsStream = AnnouncementRepository.instance.watchAnnouncements(schoolId: schoolId);
    _upcomingClubEventsFuture = _upcomingClubEvents();
  }

  Future<void> _handleRefresh() async {
    _continueReadingKey = null;
    _cachedContinueReadingFuture = null;
    _recommendedKey = null;
    _cachedRecommendedFuture = null;
    if (mounted) {
      setState(() {
        _initStreamsAndFutures();
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  void initState() {
    super.initState();
    _initStreamsAndFutures();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
    if (!_isGuest) {
      AuthService.instance.recordDailyActivity(_u!);
    }
  }

  @override
  void didUpdateWidget(UniversalHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.user?.schoolId != widget.user?.schoolId ||
        oldWidget.user?.classLevel != widget.user?.classLevel) {
      _continueReadingKey = null;
      _cachedContinueReadingFuture = null;
      _recommendedKey = null;
      _cachedRecommendedFuture = null;
      _initStreamsAndFutures();
    }
  }

  String get _timeGreeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _academicSession {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear/${startYear + 1}';
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openLibraryFolderByName(BuildContext context, AppUser user, String name) async {
    final folder = await LibraryFolderRepository.instance.rootFolderByName(name);
    if (!context.mounted) return;
    if (folder == null) {
      _open(context, LibraryHomePage(user: user));
      return;
    }
    _open(context, LibraryFolderPage(folderId: folder.id, folderName: folder.name, user: user));
  }

  // ── Continue Reading Data ──────────────────────────────────────────
  String? _continueReadingKey;
  Future<({AcademicContent content, int page, int totalPages})?>? _cachedContinueReadingFuture;
  Future<({AcademicContent content, int page, int totalPages})?> get _continueReadingFuture {
    final key = _u?.id ?? '';
    if (_cachedContinueReadingFuture == null || _continueReadingKey != key) {
      _continueReadingKey = key;
      _cachedContinueReadingFuture = _isGuest
          ? Future.value(null)
          : AcademicContentRepository.instance.continueReading(_u!.id);
    }
    return _cachedContinueReadingFuture!;
  }

  Future<void> _reopenContinueReading(
      BuildContext context, ({AcademicContent content, int page, int totalPages}) data) async {
    final localPath = await AcademicContentRepository.instance.offlineFilePath(data.content.id);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ContentViewerPage(
              fileUrl: data.content.fileUrl ?? '',
              localFilePath: localPath,
              title: data.content.title,
              kind: ViewableFileKind.pdf,
              contentId: data.content.id,
              userId: _u!.id,
            )));
  }

  // ── Pending Daily Lesson Discovery ─────────────────────────────────
  Future<({DailyLearningCourse course, DailyLearningLesson lesson, int completedCount, int totalCount})?>
      _getPendingDailyLesson() async {
    if (_isGuest) return null;
    try {
      final courses = DailyLearningRepository.instance.courses;
      if (courses.isEmpty) return null;
      for (final course in courses) {
        final progressRecord = await DailyLearningRepository.instance
            .watchProgress(_u!.id, course.id)
            .first
            .timeout(const Duration(seconds: 3), onTimeout: () => (const <String>{}, null));
        final completed = progressRecord.$1;
        for (final l in course.lessons) {
          if (!completed.contains(l.id)) {
            return (
              course: course,
              lesson: l,
              completedCount: completed.length,
              totalCount: course.lessons.length,
            );
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Weekly Activity Count ──────────────────────────────────────────
  int _weekActivityCount() {
    if (_isGuest) return 0;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final activity = _u!.weekActivityDates.toSet();
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (activity.contains(key)) count++;
    }
    return count;
  }

  // ── Marks Summary ──────────────────────────────────────────────────
  Future<({double average, List<SchoolMark> subjects})?> _latestMarksSummary() async {
    if (_isGuest || !_u!.isSchoolMember) return null;
    try {
      final all = await SchoolMarksRepository.instance.allMarksOnce(_u!.id);
      if (all.isEmpty) return null;
      AcademicSequence? latest;
      for (final m in all) {
        if (latest == null || AcademicSequence.values.indexOf(m.sequence) > AcademicSequence.values.indexOf(latest)) {
          latest = m.sequence;
        }
      }
      final subjects = all.where((m) => m.sequence == latest).toList()
        ..sort((a, b) => a.subject.compareTo(b.subject));
      return (average: averagePercentage(subjects), subjects: subjects);
    } catch (_) {
      return null;
    }
  }

  // ── Club Events ───────────────────────────────────────────────────
  Future<List<({String clubName, ClubEvent event})>> _upcomingClubEvents() async {
    if (_isGuest) return const [];
    try {
      final clubIds = await ClubRepository.instance
          .watchMyClubIds(_u!.id)
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => const <String>[]);
      if (clubIds.isEmpty) return const [];
      final clubs = await ClubRepository.instance
          .watchMyClubs(_u!.id, user: _u)
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => const <Club>[]);
      final nameById = {for (final c in clubs) c.id: c.name};
      final out = <({String clubName, ClubEvent event})>[];
      for (final id in clubIds.take(3)) {
        if (!nameById.containsKey(id)) continue;
        final events = await ClubRepository.instance
            .watchEvents(id)
            .first
            .timeout(const Duration(seconds: 4), onTimeout: () => const <ClubEvent>[]);
        for (final e in events) {
          if (e.startAt.isAfter(DateTime.now())) out.add((clubName: nameById[id] ?? '', event: e));
        }
      }
      out.sort((a, b) => a.event.startAt.compareTo(b.event.startAt));
      return out.take(2).toList();
    } catch (_) {
      return const [];
    }
  }

  String _eventTimeLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${days[d.weekday - 1]}, ${h.toString()}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  // ── Recommendations ───────────────────────────────────────────────
  String? _recommendedKey;
  Future<List<Object>>? _cachedRecommendedFuture;
  Future<List<Object>> get _recommendedFuture {
    final key = '${_u?.id}:${_u?.schoolId}:$_isGuest';
    if (_cachedRecommendedFuture == null || _recommendedKey != key) {
      _recommendedKey = key;
      _cachedRecommendedFuture = _loadRecommended();
    }
    return _cachedRecommendedFuture!;
  }

  Future<List<Object>> _loadRecommended() async {
    final contentRepo = AcademicContentRepository.instance;
    final schoolId = _u?.schoolId;
    final favSubjects = _u?.favoriteSubjects ?? const <String>[];

    var libraryItems = <AcademicContent>[];
    if (!_isGuest && favSubjects.isNotEmpty) {
      var usage = const <String, int>{};
      try {
        usage = await TestRepository.instance.subjectCompletionCountsOnce(_u!.id);
      } catch (_) {
        // Fallback to unweighted order
      }
      final ranked = rankHomeSubjectsByUsage(favSubjects, usage);
      final perSubject = await Future.wait(ranked.map((s) => contentRepo
          .watch(institutionId: schoolId, subject: s)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const <AcademicContent>[])));
      final seenIds = <String>{};
      var round = 0;
      while (libraryItems.length < 4 && perSubject.any((l) => round < l.length)) {
        for (final list in perSubject) {
          if (round >= list.length) continue;
          final item = list[round];
          if (seenIds.add(item.id)) libraryItems.add(item);
          if (libraryItems.length >= 4) break;
        }
        round++;
      }
    }
    if (libraryItems.isEmpty) {
      final fallback = await contentRepo
          .watch(institutionId: schoolId)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const <AcademicContent>[]);
      libraryItems = fallback.take(4).toList();
    }

    return libraryItems;
  }

  String _formatContentSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  // ── Build Method ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: ac.bg,
      child: SafeArea(
        child: RefreshIndicator(
          color: ac.primary,
          backgroundColor: ac.surf,
          onRefresh: _handleRefresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _topBar(context),
              const SizedBox(height: 12),
              _greetingHeader(context),
              const SizedBox(height: 14),
              _commandCenterHero(context),
              const SizedBox(height: 18),
              _progressAndGoalsStrip(context),
              const SizedBox(height: 24),
              _sectionHeader('Academic Hubs'),
              const SizedBox(height: 12),
              _academicHubsGrid(context),
              const SizedBox(height: 12),
              _secondaryToolsRow(context),
              const SizedBox(height: 24),
              _sectionHeader("Today's Schedule & Tasks"),
              const SizedBox(height: 12),
              _scheduleAndTasksRow(context),
              const SizedBox(height: 24),
              _sectionHeader("Campus & Community"),
              const SizedBox(height: 12),
              _campusAndCommunityRow(context),
              const SizedBox(height: 24),
              _sectionHeader(
                'Recommended for You',
                onViewAll: () => _open(context, LibraryHomePage(user: _userOrGuest)),
              ),
              const SizedBox(height: 12),
              _recommendedRow(context),
              const SizedBox(height: 24),
              _academicProfileSummaryCard(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context) {
    final schoolLabel = (!_isGuest && _u!.isSchoolMember && _u!.schoolName.isNotEmpty)
        ? _u!.schoolName
        : (_u?.classLevel.isNotEmpty == true ? _u!.classLevel : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu_rounded, color: ac.txt, size: 24),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Navigation Menu',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Branding.current.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: ac.primary),
                ),
                if (schoolLabel != null)
                  Text(
                    schoolLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: ac.txt2),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: ac.txt2, size: 22),
            tooltip: 'Search',
            onPressed: () => _open(context, SearchPage(user: _userOrGuest)),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.chat_bubble_outline_rounded, color: ac.txt2, size: 20),
                tooltip: 'Messages',
                onPressed: () => _open(context, MessagesHomePage(user: _userOrGuest)),
              ),
              if (!_isGuest) _messagesTopUnreadBadge(),
            ],
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: ac.txt2, size: 22),
                tooltip: 'Notifications',
                onPressed: () => _open(context, NotificationsPage(user: _userOrGuest)),
              ),
              if (!_isGuest)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: ac.grn, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          UserAvatar(
            initials: _isGuest || _userOrGuest.name.isEmpty ? '?' : _userOrGuest.name[0].toUpperCase(),
            radius: 17,
            photoUrl: _u?.photoUrl,
            onTap: () => _open(context, ProfilePage(user: _userOrGuest)),
          ),
        ],
      ),
    );
  }

  Widget _messagesTopUnreadBadge() {
    final uid = _u?.id ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<Conversation>>(
      stream: _conversationsStream ?? const Stream.empty(),
      builder: (context, snap) {
        final total = (snap.data ?? const <Conversation>[])
            .fold<int>(0, (sum, c) => sum + (c.unreadCount[uid] ?? 0));
        if (total <= 0) return const SizedBox.shrink();
        return Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
            constraints: const BoxConstraints(minWidth: 15),
            decoration: BoxDecoration(color: ac.red, borderRadius: BorderRadius.circular(8)),
            child: Text(
              total > 9 ? '9+' : '$total',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  // ── Greeting Header ────────────────────────────────────────────────
  Widget _greetingHeader(BuildContext context) {
    final firstName = _isGuest
        ? 'Student'
        : (_u!.name.trim().isEmpty ? 'Student' : _u!.name.trim().split(' ').first);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_timeGreeting, $firstName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ac.txt,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isGuest
                      ? 'Welcome to your academic learning hub.'
                      : (_u!.classLevel.isNotEmpty
                          ? '${_u!.classLevel} · Ready to master your subjects today?'
                          : 'Your academic command center is ready.'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ac.primaryBg,
              borderRadius: BorderRadius.circular(Rad.xs),
              border: Border.all(color: ac.primary.withValues(alpha: 0.15)),
            ),
            child: Text(
              '$_academicSession Session',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ac.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Academic Command Center Hero ("What should I do now?") ─────────
  Widget _commandCenterHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<({AcademicContent content, int page, int totalPages})?>(
        future: _continueReadingFuture,
        builder: (context, readSnap) {
          final readingData = readSnap.data;

          return StreamBuilder<DailyLearningStreak?>(
            stream: _streakStream ?? const Stream.empty(),
            builder: (context, streakSnap) {
              final streak = streakSnap.data;
              final now = DateTime.now();
              final streakDoneToday = streak?.lastCompletedDate != null &&
                  streak!.lastCompletedDate!.year == now.year &&
                  streak.lastCompletedDate!.month == now.month &&
                  streak.lastCompletedDate!.day == now.day;

              return FutureBuilder<
                  ({
                    DailyLearningCourse course,
                    DailyLearningLesson lesson,
                    int completedCount,
                    int totalCount
                  })?>(
                future: _pendingDailyLessonFuture,
                builder: (context, pendingSnap) {
                  final pending = pendingSnap.data;

                  // 1. Priority: Continue Reading if available
                  if (readingData != null) {
                    final pct = readingData.totalPages > 0
                        ? (readingData.page / readingData.totalPages).clamp(0.0, 1.0)
                        : 0.0;
                    return _heroCardLayout(
                      context,
                      eyebrow: 'CONTINUE READING',
                      eyebrowIcon: Icons.menu_book_rounded,
                      eyebrowColor: ac.gold,
                      title: readingData.content.title,
                      subtitle:
                          '${readingData.content.subject.isNotEmpty ? '${readingData.content.subject} · ' : ''}Page ${readingData.page} of ${readingData.totalPages}',
                      progressPct: pct,
                      progressLabel: '${(pct * 100).round()}% complete',
                      primaryLabel: 'Resume Reading',
                      primaryIcon: Icons.arrow_forward_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _reopenContinueReading(context, readingData);
                      },
                      secondaryLabel: 'Browse Library',
                      onSecondary: () => _open(context, LibraryHomePage(user: _userOrGuest)),
                    );
                  }

                  // 2. Priority: Daily Challenge pending
                  if (pending != null && !streakDoneToday) {
                    final streakCount = streak?.currentStreak ?? 0;
                    final progressPct = pending.totalCount > 0
                        ? (pending.completedCount / pending.totalCount).clamp(0.0, 1.0)
                        : 0.0;

                    return _heroCardLayout(
                      context,
                      eyebrow: streakCount > 0 ? 'DAILY CHALLENGE · DAY ${streakCount + 1}' : 'DAILY CHALLENGE',
                      eyebrowIcon: Icons.local_fire_department_rounded,
                      eyebrowColor: ac.org,
                      title: '${pending.course.title}: ${pending.lesson.title}',
                      subtitle:
                          '${pending.lesson.questions.length} quick questions · Keep your streak alive & earn XP',
                      progressPct: progressPct,
                      progressLabel:
                          'Lesson ${pending.completedCount + 1} of ${pending.totalCount} in course',
                      primaryLabel: 'Start Challenge',
                      primaryIcon: Icons.play_arrow_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _open(
                          context,
                          DailyLearningLessonPage(
                            user: _userOrGuest,
                            course: pending.course,
                            lesson: pending.lesson,
                          ),
                        );
                      },
                      secondaryLabel: 'View All Courses',
                      onSecondary: () => _open(context, CoursesHomePage(user: _u)),
                    );
                  }

                  // 3. Priority: Daily Challenge completed today
                  if (streakDoneToday) {
                    final streakCount = streak?.currentStreak ?? 1;
                    return _heroCardLayout(
                      context,
                      eyebrow: 'DAILY GOAL ACHIEVED',
                      eyebrowIcon: Icons.verified_rounded,
                      eyebrowColor: ac.grn,
                      title: 'Great discipline today! 🔥',
                      subtitle:
                          'You\'ve secured your $streakCount-day learning streak. Explore past papers or take an Academia Quiz to earn more XP.',
                      primaryLabel: 'Explore Library',
                      primaryIcon: Icons.menu_book_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _open(context, LibraryHomePage(user: _userOrGuest));
                      },
                      secondaryLabel: 'Practice Quizzes',
                      onSecondary: () => _open(context, QuizCategoriesPage(user: _userOrGuest)),
                    );
                  }

                  // 4a. Staff: their working tools, not "start your
                  // learning journey" (which read as student copy).
                  final staff = _u;
                  if (staff != null && !staff.isStudent && staff.canRecordAnyMarks) {
                    return _heroCardLayout(
                      context,
                      eyebrow: 'YOUR CLASSES',
                      eyebrowIcon: Icons.co_present_rounded,
                      eyebrowColor: ac.gold,
                      title: 'Ready for today\'s lessons',
                      subtitle: 'Enter marks for a whole class, check your teaching timetable, or message your students.',
                      primaryLabel: 'Enter Marks',
                      primaryIcon: Icons.edit_note_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _open(context, MarksPage(user: staff));
                      },
                      secondaryLabel: 'My Timetable',
                      onSecondary: () => _open(context, TimetablePage(user: staff)),
                    );
                  }

                  // 4. Default for new accounts or guests
                  return _heroCardLayout(
                    context,
                    eyebrow: 'ACADEMIC COMMAND CENTER',
                    eyebrowIcon: Icons.explore_rounded,
                    eyebrowColor: ac.gold,
                    title: 'Start Your Learning Journey',
                    subtitle:
                        'Access official textbooks, solved past questions, subject drills, and intellectual masterclasses.',
                    primaryLabel: 'Explore Library',
                    primaryIcon: Icons.search_rounded,
                    onPrimary: () {
                      HapticFeedback.selectionClick();
                      _open(context, LibraryHomePage(user: _userOrGuest));
                    },
                    secondaryLabel: 'Start Daily Challenge',
                    onSecondary: () => _open(context, DailyLearningHubPage(user: _userOrGuest)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _heroCardLayout(
    BuildContext context, {
    required String eyebrow,
    required IconData eyebrowIcon,
    required Color eyebrowColor,
    required String title,
    required String subtitle,
    double? progressPct,
    String? progressLabel,
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.lg),
        gradient: LinearGradient(
          colors: [
            ac.navy,
            const Color(0xFF0F3A30),
            ac.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: _glow,
      ),
      child: Stack(
        children: [
          // Subtle background decorative radial accent
          Positioned(
            right: -40,
            bottom: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ac.gold.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eyebrow tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(Rad.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(eyebrowIcon, color: eyebrowColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            eyebrow,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.35,
                  ),
                ),
                if (progressPct != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPct,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(ac.gold),
                          ),
                        ),
                      ),
                      if (progressLabel != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          progressLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Rad.xs),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Rad.xs),
                        onTap: onPrimary,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(primaryIcon, size: 16, color: ac.navy),
                              const SizedBox(width: 6),
                              Text(
                                primaryLabel,
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ac.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Rad.xs),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onSecondary();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Text(
                              secondaryLabel,
                              style: GoogleFonts.sora(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Goal-Gradient Momentum Strip ───────────────────────────────────
  Widget _progressAndGoalsStrip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: BorderRadius.circular(Rad.md),
          border: Border.all(color: ac.bdr.withValues(alpha: 0.5)),
          boxShadow: _glow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: ac.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Academic Momentum',
                      style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: ac.txt),
                    ),
                  ],
                ),
                Text(
                  'Goal Gradient Tracker',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: ac.txt2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StreamBuilder<DailyLearningStreak?>(
              stream: _streakStream ?? const Stream.empty(),
              builder: (context, streakSnap) {
                final streak = streakSnap.data;
                final streakCount = streak?.currentStreak ?? 0;
                final now = DateTime.now();
                final streakDone = streak?.lastCompletedDate != null &&
                    streak!.lastCompletedDate!.year == now.year &&
                    streak.lastCompletedDate!.month == now.month &&
                    streak.lastCompletedDate!.day == now.day;

                return StreamBuilder<(int, int)>(
                  stream: _xpStream ?? const Stream.empty(),
                  builder: (context, xpSnap) {
                    final lifetimeXp = _isGuest ? 0 : (xpSnap.data?.$2 ?? 0);

                    return FutureBuilder<Map<String, int>>(
                      future: _completionCountsFuture ?? Future.value(const {}),
                      builder: (context, badgeSnap) {
                        final quizzesPassed =
                            (badgeSnap.data ?? const {}).values.fold<int>(0, (s, v) => s + v);
                        final activeDays = _weekActivityCount();

                        return Row(
                          children: [
                            Expanded(
                              child: _metricTile(
                                icon: Icons.local_fire_department_rounded,
                                iconColor: ac.org,
                                iconBg: ac.orgBg,
                                value: '$streakCount d',
                                label: streakDone ? 'Streak Active' : 'Streak Pending',
                                onTap: () => _open(context, DailyLearningHubPage(user: _userOrGuest)),
                              ),
                            ),
                            Container(width: 1, height: 38, color: ac.bdr.withValues(alpha: 0.6)),
                            Expanded(
                              child: _metricTile(
                                icon: Icons.calendar_today_rounded,
                                iconColor: ac.primary,
                                iconBg: ac.primaryBg,
                                value: '$activeDays/7',
                                label: 'Days Active',
                                onTap: () => _open(context, ProfilePage(user: _userOrGuest)),
                              ),
                            ),
                            Container(width: 1, height: 38, color: ac.bdr.withValues(alpha: 0.6)),
                            Expanded(
                              child: _metricTile(
                                icon: Icons.stars_rounded,
                                iconColor: ac.gold,
                                iconBg: ac.goldBg,
                                value: '$lifetimeXp',
                                label: 'XP Points',
                                onTap: () => _open(context, XpDashboardPage(user: _userOrGuest)),
                              ),
                            ),
                            Container(width: 1, height: 38, color: ac.bdr.withValues(alpha: 0.6)),
                            Expanded(
                              child: _metricTile(
                                icon: Icons.military_tech_rounded,
                                iconColor: ac.pur,
                                iconBg: ac.purBg,
                                value: '$quizzesPassed',
                                label: 'Quizzes Done',
                                onTap: () => _open(context, QuizCategoriesPage(user: _userOrGuest)),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            // School GPA summary row if enrolled in school and marks exist
            if (!_isGuest && _u!.isSchoolMember) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: ac.bdr.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              FutureBuilder<({double average, List<SchoolMark> subjects})?>(
                future: _latestMarksFuture,
                builder: (context, marksSnap) {
                  final marksData = marksSnap.data;
                  if (marksData == null || marksData.subjects.isEmpty) {
                    return InkWell(
                      onTap: () => _open(context, MarksPage(user: _userOrGuest)),
                      child: Row(
                        children: [
                          Icon(Icons.assessment_outlined, color: ac.txt2, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'View your official school marks & grade reports',
                              style: GoogleFonts.inter(fontSize: 11, color: ac.txt2),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: ac.muted, size: 18),
                        ],
                      ),
                    );
                  }
                  return InkWell(
                    onTap: () => _open(context, MarksPage(user: _userOrGuest)),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: ac.primaryBg,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${marksData.average.round()}%',
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: ac.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Term Average · ${marksData.subjects.length} recorded subject${marksData.subjects.length == 1 ? '' : 's'}',
                                style: GoogleFonts.sora(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: ac.txt,
                                ),
                              ),
                              Text(
                                marksData.subjects.take(3).map((s) => s.subject).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 10, color: ac.txt2),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: ac.muted, size: 18),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(Rad.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: ac.txt),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: ac.txt2),
            ),
          ],
        ),
      ),
    );
  }

  // ── Structured Academic Hubs (2x2 Grid) ────────────────────────────
  Widget _academicHubsGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _academicHubCard(
                  context,
                  title: 'Academia Library',
                  subtitle: 'Textbooks, revision & notes',
                  icon: Icons.local_library_rounded,
                  iconColor: ac.primary,
                  iconBg: ac.primaryBg,
                  onTap: () => _open(context, LibraryHomePage(user: _userOrGuest)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _academicHubCard(
                  context,
                  title: 'Past Questions',
                  subtitle: 'GCE & national exam papers',
                  icon: Icons.assignment_rounded,
                  iconColor: ac.grn,
                  iconBg: ac.grnBg,
                  onTap: () => _openLibraryFolderByName(context, _userOrGuest, 'Past Papers'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _academicHubCard(
                  context,
                  title: 'Academia Quizzes',
                  subtitle: 'Timed MCQ drills & instant XP',
                  icon: Icons.quiz_rounded,
                  iconColor: ac.gold,
                  iconBg: ac.goldBg,
                  onTap: () => _open(context, QuizCategoriesPage(user: _userOrGuest)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _academicHubCard(
                  context,
                  title: 'Academia Courses',
                  subtitle: 'Curated skill masterclasses',
                  icon: Icons.school_rounded,
                  iconColor: ac.pur,
                  iconBg: ac.purBg,
                  onTap: () => _open(context, CoursesHomePage(user: _u)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _academicHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr.withValues(alpha: 0.7)),
            boxShadow: _glow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(Rad.xs),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  Icon(Icons.arrow_outward_rounded, size: 16, color: ac.muted),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 10, color: ac.txt2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Secondary Tools Scannable Row ──────────────────────────────────
  Widget _secondaryToolsRow(BuildContext context) {
    final isSchoolMember = !_isGuest && _u!.isSchoolMember;

    final tools = <(String, IconData, Color, VoidCallback)>[
      ('Marks', Icons.assessment_outlined, ac.primary,
          () => _open(context, MarksPage(user: _userOrGuest))),
      ('Homework', Icons.menu_book_outlined, ac.org,
          () => _open(context, HomeworkPage(user: _userOrGuest))),
      ('Timetable', Icons.calendar_month_outlined, ac.grn,
          () => _open(context, TimetablePage(user: _userOrGuest))),
      ('School Connect', Icons.forum_outlined, ac.pur,
          () => _open(context, SchoolConnectPage(user: _userOrGuest))),
      ('Daily Notices', Icons.campaign_outlined, ac.org,
          () => _open(context, DailyNoticesPage(user: _userOrGuest))),
      if (!_isGuest && (_u!.isAdmin || _u!.isTeacher || _u!.isSchoolClassMaster || _u!.canManageSchool))
        ('Exam Composer', Icons.assignment_outlined, ac.primary,
            () => _open(context, ExamListPage(user: _u!))),
      ('Dictionary', Icons.spellcheck_rounded, ac.primary,
          () => _open(context, const DictionaryScreen())),
      ('Study Groups', Icons.groups_rounded, ac.grn,
          () => _open(context, ClubsPage(user: _userOrGuest))),
      ('Daily Challenges', Icons.local_fire_department_rounded, ac.org,
          () => _open(context, DailyLearningHubPage(user: _userOrGuest))),
      ('Magazine', Icons.auto_stories_rounded, ac.gold,
          () => _open(context, MagazineFeedPage(user: _userOrGuest))),
      if (_u?.isSuperAdmin == true)
        ('Command Center', Icons.admin_panel_settings, Colors.red,
            () => _open(context, const CommandCenterScreen())),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, icon, color, onTap) = tools[i];
          return ActionChip(
            avatar: Icon(icon, size: 16, color: color),
            label: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: ac.txt),
            ),
            backgroundColor: ac.surf,
            side: BorderSide(color: ac.bdr.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
            onPressed: () {
              HapticFeedback.selectionClick();
              onTap();
            },
          );
        },
      ),
    );
  }

  // ── Schedule & Tasks Row ───────────────────────────────────────────
  Widget _scheduleAndTasksRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _panelCard(
                title: "Today's Schedule",
                actionLabel: 'View timetable',
                onAction: () {
                  if (!_isGuest && _u!.isSchoolMember) {
                    _open(context, TimetablePage(user: _u!));
                  } else {
                    _open(context, PersonalStudyPage(user: _userOrGuest));
                  }
                },
                child: _scheduleCardContent(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _panelCard(
                title: 'My Tasks & Homework',
                actionLabel: 'View all',
                onAction: () {
                  if (!_isGuest && _u!.isSchoolMember) {
                    _open(context, HomeworkPage(user: _u!));
                  } else {
                    _open(context, LibraryHomePage(user: _userOrGuest));
                  }
                },
                child: _tasksCardContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleCardContent(BuildContext context) {
    if (_isGuest) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _open(context, PersonalStudyPage(user: _userOrGuest));
        },
        borderRadius: BorderRadius.circular(Rad.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ac.primaryBg,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: ac.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: ac.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Timetable',
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set up your revision blocks',
                      style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ac.primary, size: 16),
            ],
          ),
        ),
      );
    }

    // If school member, check official school timetable first
    final schoolId = _u!.schoolId;
    if (_u!.isSchoolMember && schoolId != null && schoolId.isNotEmpty && _u!.classLevel.isNotEmpty) {
      return StreamBuilder<List<SchoolTimetableSlot>>(
        stream: _timetableStream ?? const Stream.empty(),
        builder: (context, snap) {
          final slots = snap.data ?? const <SchoolTimetableSlot>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (slots.isNotEmpty) {
            final shown = slots.take(2).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in shown) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 30,
                        decoration: BoxDecoration(color: ac.primary, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.startTime} - ${s.endTime}',
                              style: GoogleFonts.inter(fontSize: 10, color: ac.txt2),
                            ),
                            Text(
                              s.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.txt),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (slots.length > 2)
                  Text(
                    '+${slots.length - 2} more period${slots.length - 2 == 1 ? '' : 's'} today',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ac.primary),
                  ),
              ],
            );
          }

          // Fallback to personal study slots if school timetable is empty
          return _personalStudySlotsFallback();
        },
      );
    }

    return _personalStudySlotsFallback();
  }

  Widget _personalStudySlotsFallback() {
    final uid = _u?.id ?? '';
    if (uid.isEmpty) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _open(context, PersonalStudyPage(user: _userOrGuest));
        },
        borderRadius: BorderRadius.circular(Rad.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ac.primaryBg,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: ac.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: ac.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Study Routine',
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add revision blocks for today',
                      style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ac.primary, size: 16),
            ],
          ),
        ),
      );
    }
    return StreamBuilder<List<PersonalStudySlot>>(
      stream: _personalStudyStream ?? const Stream.empty(),
      builder: (context, snap) {
        final slots = snap.data ?? const <PersonalStudySlot>[];
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (slots.isEmpty) {
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(context, PersonalStudyPage(user: _userOrGuest));
            },
            borderRadius: BorderRadius.circular(Rad.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ac.primaryBg,
                borderRadius: BorderRadius.circular(Rad.sm),
                border: Border.all(color: ac.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: ac.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan Study Routine',
                          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add study slots for today',
                          style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ac.primary, size: 16),
                ],
              ),
            ),
          );
        }
        final shown = slots.take(2).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in shown) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(color: ac.grn, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.startTime} - ${s.endTime}',
                          style: GoogleFonts.inter(fontSize: 10, color: ac.txt2),
                        ),
                        Text(
                          s.activity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.txt),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (slots.length > 2)
              Text(
                '+${slots.length - 2} more revision slot${slots.length - 2 == 1 ? '' : 's'}',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ac.grn),
              ),
          ],
        );
      },
    );
  }

  Widget _tasksCardContent(BuildContext context) {
    if (_isGuest) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _open(context, DailyLearningHubPage(user: _userOrGuest));
        },
        borderRadius: BorderRadius.circular(Rad.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ac.goldBg,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: ac.gold.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: ac.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Practice (+50 XP)',
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.gold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Practice quizzes & tests today',
                      style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ac.gold, size: 16),
            ],
          ),
        ),
      );
    }

    final schoolId = _u!.schoolId;
    if (_u!.isSchoolMember && schoolId != null && schoolId.isNotEmpty && _u!.classLevel.isNotEmpty) {
      return StreamBuilder<List<Homework>>(
        stream: _homeworkStream ?? const Stream.empty(),
        builder: (context, snap) {
          final homeworkList = snap.data ?? const <Homework>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }

          if (homeworkList.isNotEmpty) {
            final shown = homeworkList.take(2).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final h in shown) ...[
                  InkWell(
                    onTap: () => _open(context, HomeworkPage(user: _u!)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(color: ac.org, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                    fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt),
                              ),
                              Text(
                                '${h.subject} · Due ${_formatDueDate(h.dueAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (homeworkList.length > 2)
                  Text(
                    '+${homeworkList.length - 2} more assignment${homeworkList.length - 2 == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ac.primary),
                  ),
              ],
            );
          }

          return _readingTaskFallback(context);
        },
      );
    }

    return _readingTaskFallback(context);
  }

  Widget _readingTaskFallback(BuildContext context) {
    return FutureBuilder<({AcademicContent content, int page, int totalPages})?>(
      future: _continueReadingFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final data = snap.data;
        if (data == null) {
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(context, DailyLearningHubPage(user: _userOrGuest));
            },
            borderRadius: BorderRadius.circular(Rad.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ac.goldBg,
                borderRadius: BorderRadius.circular(Rad.sm),
                border: Border.all(color: ac.gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: ac.grn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Homework Clear! (+50 XP)',
                          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Take today\'s daily challenge',
                          style: GoogleFonts.inter(fontSize: 9.5, color: ac.gold, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ac.gold, size: 16),
                ],
              ),
            ),
          );
        }
        final pct = data.totalPages > 0 ? (data.page / data.totalPages).clamp(0.0, 1.0) : 0.0;
        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _reopenContinueReading(context, data);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(color: ac.primary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reading task · ${(pct * 100).round()}% finished',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: ac.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDueDate(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays > 1 && diff.inDays < 7) return 'in ${diff.inDays} days';
    return '${due.day}/${due.month}';
  }

  Widget _emptyCardState({required IconData icon, required String message}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ac.muted, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _panelCard({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr.withValues(alpha: 0.6)),
        boxShadow: _glow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.txt),
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAction();
                },
                child: Text(
                  actionLabel,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Campus & Community Pulse ───────────────────────────────────────
  Widget _campusAndCommunityRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _panelCard(
                title: 'Announcements',
                actionLabel: 'View all',
                onAction: () => _open(
                  context,
                  AnnouncementsPage(
                    user: _userOrGuest,
                    canPost: !_isGuest && _u!.canPostAnnouncement,
                  ),
                ),
                child: _announcementsContent(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _panelCard(
                title: 'My Study Groups',
                actionLabel: 'Explore',
                onAction: () => _open(context, ClubsPage(user: _userOrGuest)),
                child: _myClubContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _announcementsContent(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: _announcementsStream ?? const Stream.empty(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final items = snap.data ?? const <Announcement>[];
        if (items.isEmpty) {
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(
                context,
                AnnouncementsPage(user: _userOrGuest, canPost: !_isGuest && _u!.canPostAnnouncement),
              );
            },
            borderRadius: BorderRadius.circular(Rad.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ac.purBg,
                borderRadius: BorderRadius.circular(Rad.sm),
                border: Border.all(color: ac.pur.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, color: ac.pur, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'School Bulletin',
                          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.pur),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View noticeboard & updates',
                          style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ac.pur, size: 16),
                ],
              ),
            ),
          );
        }
        final top = items.first;
        return InkWell(
          onTap: () => _open(
            context,
            AnnouncementsPage(user: _userOrGuest, canPost: !_isGuest && _u!.canPostAnnouncement),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      'LATEST',
                      style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: ac.pur),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      top.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                top.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt, height: 1.3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _myClubContent(BuildContext context) {
    if (_isGuest) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _open(context, ClubsPage(user: _userOrGuest));
        },
        borderRadius: BorderRadius.circular(Rad.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ac.grnBg,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: ac.grn.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_outlined, color: ac.grn, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Circles',
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.grn),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore collaborative groups',
                      style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ac.grn, size: 16),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<List<({String clubName, ClubEvent event})>>(
      future: _upcomingClubEventsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(context, ClubsPage(user: _userOrGuest));
            },
            borderRadius: BorderRadius.circular(Rad.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ac.grnBg,
                borderRadius: BorderRadius.circular(Rad.sm),
                border: Border.all(color: ac.grn.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.group_add_outlined, color: ac.grn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Study Circles',
                          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.grn),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Connect with peer revision groups',
                          style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ac.grn, size: 16),
                ],
              ),
            ),
          );
        }
        final first = items.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              first.clubName.isNotEmpty ? '${first.clubName}: ${first.event.title}' : first.event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.txt, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              _eventTimeLabel(first.event.startAt),
              style: GoogleFonts.inter(fontSize: 9.5, color: ac.muted),
            ),
          ],
        );
      },
    );
  }

  // ── Section Header ─────────────────────────────────────────────────
  Widget _sectionHeader(String title, {VoidCallback? onViewAll, String viewAllLabel = 'View all'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt),
          ),
          if (onViewAll != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.xs),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onViewAll();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    viewAllLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ac.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Recommended For You ────────────────────────────────────────────
  Widget _recommendedRow(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _recommendedFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 168,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Couldn't load recommendations",
              style: GoogleFonts.inter(fontSize: 12, color: ac.red),
            ),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No items to recommend yet. Explore the Library to discover materials.',
              style: GoogleFonts.inter(fontSize: 12, color: ac.muted),
            ),
          );
        }
        return SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final it = items[i];
              if (it is AcademicContent) return _recommendedCard(context, it);
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _recommendedCard(BuildContext context, AcademicContent item) {
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () {
          HapticFeedback.selectionClick();
          _open(context, ContentDetailsPage(contentId: item.id, user: _userOrGuest));
        },
        child: Container(
          width: 156,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr.withValues(alpha: 0.6)),
            boxShadow: _glow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              SizedBox(
                height: 68,
                width: double.infinity,
                child: (item.thumbnailUrl ?? '').isNotEmpty
                    ? Image.network(
                        item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbnailFallback(item),
                      )
                    : _thumbnailFallback(item),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_rounded, size: 12, color: ac.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.contentType.label,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: ac.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatContentSize(item.fileSizeBytes),
                          style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                        ),
                        Icon(Icons.bookmark_outline_rounded, size: 15, color: ac.muted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnailFallback(AcademicContent item) {
    return Container(
      color: ac.primaryBg,
      child: Center(
        child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  // ── Academic Profile Summary Card (Endowment Footer) ───────────────
  Widget _academicProfileSummaryCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: BorderRadius.circular(Rad.md),
          border: Border.all(color: ac.bdr.withValues(alpha: 0.6)),
          boxShadow: _glow,
        ),
        child: Row(
          children: [
            UserAvatar(
              initials: _isGuest || _userOrGuest.name.isEmpty ? '?' : _userOrGuest.name[0].toUpperCase(),
              radius: 20,
              photoUrl: _u?.photoUrl,
              onTap: () => _open(context, ProfilePage(user: _userOrGuest)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isGuest ? 'Guest Learner' : _userOrGuest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: ac.txt),
                  ),
                  Text(
                    _isGuest
                        ? 'Sign in to sync your learning across devices'
                        : (_u!.isSchoolMember
                            ? '${_u!.schoolName} · ${_u!.classLevel}'
                            : 'Personal Academic Workspace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: ac.primaryBg,
              borderRadius: BorderRadius.circular(Rad.xs),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.xs),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _open(context, ProfilePage(user: _userOrGuest));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profile',
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ac.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: ac.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
