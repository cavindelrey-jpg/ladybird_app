// lib/widgets/app_drawer.dart
// Global navigation drawer, organized into 4 hierarchical groups per the
// architecture brief's item 13: Content (Home/Academia Courses/Academia
// Library/Past Questions), Assessment (Academia Tests/Academia Quizzes/
// Create Quiz), Communication (Magazine/Messaging/Clubs), Settings &
// Personalization (Settings/Notifications/Support/Profile) -- plus
// (lecturer+) the Grading Queue, which doesn't fit any of the four.
// Shared by the universal dashboard for every account type.
//
// Guest (user == null) can open every destination to browse, but write
// actions inside those destinations should independently refuse Guests —
// this drawer only controls navigation, not the read/write gate itself.

import 'package:flutter/material.dart';
import '../screens/dictionary_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../features/onboarding/account_choice_screen.dart';
import '../screens/login_screen.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/academic_content/library_folder_page.dart';
import '../repositories/library_folder_repository.dart';
import '../features/messages/messages_home_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../pages/notifications_page.dart';
import '../pages/help_support_page.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/testing/grading_page.dart';
import '../features/testing/test_composer_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/teacher_management_page.dart';
import '../features/onboarding/school_admin_page.dart';
import '../features/school/school_calendar_page.dart';
import '../features/school/class_group_launcher.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/exam_composer/exam_list_page.dart';
import '../features/school/student_roster_page.dart';

class AppDrawer extends StatelessWidget {
  final AppUser? user;
  final VoidCallback? onHomeTap;
  const AppDrawer({super.key, this.user, this.onHomeTap});

  bool get _isGuest => user == null;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Drawer(
      backgroundColor: ac.surf,
      child: SafeArea(
        child: Column(children: [
          _header(context, ac),
          Divider(height: 1, color: ac.bdr2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              children: [
                // Architecture brief item 13: four hierarchical groups
                // (Content/Assessment/Communication/Settings) replacing
                // what used to be a flatter, less organized list.
                _sectionLabel(ac, 'Content'),
                _item(context, ac, Icons.menu_book, 'Academia Dictionary', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const DictionaryScreen()));
                }),

                _item(context, ac, Icons.home_rounded, 'Home', () { if (onHomeTap != null) onHomeTap!(); }),
                // "Course Navigation" used to be a separate top-level
                // entry pointing at CourseNavigationPage -- but
                // CoursesMarketplacePage already has its own prominent
                // "Browse by Curriculum" CTA into that exact same page.
                // Two routes to the same conceptual place; removed the
                // duplicate rather than keep both.
                _item(context, ac, Icons.school_rounded, 'Academia Courses', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CoursesHomePage(user: user)));
                }),
                _item(context, ac, Icons.folder_copy_rounded, 'Academia Library', () {
                  Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LibraryHomePage(user: (user ?? AppUser.guest()))));
                }),
                _item(context, ac, Icons.description_rounded, 'Past Questions', () {
                  _openLibraryFolderByName(context, user ?? AppUser.guest(), 'Past Papers');
                }),

                _sectionLabel(ac, 'Assessment'),
                // Tests and Quizzes intentionally open the SAME browse
                // tree (QuizCategoriesPage) -- this codebase doesn't
                // model them as separate systems (see
                // tests_subject_picker_page.dart's own file comment).
                // Kept as two entries to match the requested structure,
                // not because they lead anywhere different.
                _item(context, ac, Icons.assignment_rounded, 'Academia Tests', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => QuizCategoriesPage(user: user ?? AppUser.guest())));
                }),
                _item(context, ac, Icons.quiz_rounded, 'Academia Quizzes', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => QuizCategoriesPage(user: user ?? AppUser.guest())));
                }),
                // TestRepository.createTest() had no caller anywhere in
                // the app until this entry existed — tests could only
                // have been created straight in the Firestore console.
                if (!_isGuest && user!.hasMinRole(UserRole.lecturer))
                  _item(context, ac, Icons.post_add_rounded, 'Create Quiz', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TestComposerPage(author: user!)));
                  }),

                // School Connect/Marks/Timetable already existed but were
                // only reachable buried in Profile's "School Navigation"
                // section -- surfaced here too, since the drawer is the
                // one navigation surface open from anywhere in the app,
                // not just after scrolling into Profile.
                _sectionLabel(ac, 'My School'),
                _item(context, ac, Icons.forum_outlined, 'School Connect', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SchoolConnectPage(user: user ?? AppUser.guest())));
                }),
                _item(context, ac, Icons.assessment_outlined, 'Marks', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MarksPage(user: user ?? AppUser.guest())));
                }),
                _item(context, ac, Icons.menu_book_outlined, 'Homework', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => HomeworkPage(user: user ?? AppUser.guest())));
                }),
                _item(context, ac, Icons.calendar_month_outlined, 'Timetable', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TimetablePage(user: user ?? AppUser.guest())));
                }),
                _item(context, ac, Icons.campaign_outlined, 'Daily Notices', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DailyNoticesPage(user: user ?? AppUser.guest())));
                }),
                _item(context, ac, Icons.event_note_outlined, 'School Calendar', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SchoolCalendarPage(user: user ?? AppUser.guest())));
                }),
                if (!_isGuest && (user!.isAdmin || user!.isTeacher || user!.isSchoolClassMaster || user!.canManageSchool))
                  _item(context, ac, Icons.assignment_outlined, 'Exam Composer', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ExamListPage(user: user!)));
                  }),
                if (!_isGuest && canOpenClassGroup(user!))
                  _item(context, ac, Icons.forum_outlined, 'Class Group',
                      // The drawer's context is gone once it closes; the launcher awaits
                      // network calls, so it needs the Navigator's long-lived context.
                      () => openClassGroup(Navigator.of(context).context, user!)),

                if (!_isGuest && (user!.isAdmin || user!.canManageSchool)) ...[
                  _sectionLabel(ac, 'School Administration'),
                  _item(context, ac, Icons.badge_outlined, 'Teacher Management', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TeacherManagementPage(admin: user!)));
                  }),
                  _item(context, ac, Icons.people_alt_outlined, 'Class Lists & Students', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StudentRosterPage(user: user!)));
                  }),
                  if (user!.canManageUsers)
                    _item(context, ac, Icons.vpn_key_outlined, 'Access Codes', () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SchoolAdminPage(user: user!)));
                    }),
                ],

                _sectionLabel(ac, 'Communication'),
                _item(context, ac, Icons.menu_book_rounded, 'Magazine', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MagazineFeedPage(user: user)));
                }),
                _item(context, ac, Icons.chat_bubble_outline_rounded, 'Messaging', () {
                  Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MessagesHomePage(user: (user ?? AppUser.guest()))));
                }),
                _item(context, ac, Icons.groups_rounded, 'Groups', () {
                  Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ClubsPage(user: (user ?? AppUser.guest()))));
                }),

                _sectionLabel(ac, 'Settings & Personalization'),
                _item(context, ac, Icons.settings_outlined, 'Settings', () {
                  Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SettingsPage(user: (user ?? AppUser.guest()))));
                }),
                _item(context, ac, Icons.notifications_outlined, 'Notifications', () {
                  Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NotificationsPage(user: user ?? AppUser.guest())));
                }),
                _item(context, ac, Icons.help_outline_rounded, 'Support',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const HelpSupportPage()))),
                _item(context, ac, Icons.person_outline_rounded, 'Profile', () {
                  Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProfilePage(user: (user ?? AppUser.guest()))));
                }),

                // Doesn't fit any of the 4 requested groups (it's an
                // internal staff workflow, not user-facing content
                // navigation) -- kept as a clearly separated trailing
                // section rather than forced into one of the four.
                if (!_isGuest && user!.hasMinRole(UserRole.lecturer)) ...[
                  Divider(height: 24, thickness: 1, indent: 16, endIndent: 16, color: ac.bdr2),
                  _item(context, ac, Icons.rate_review_rounded, 'Grading Queue', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GradingPage(grader: user!)));
                  }),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: ac.bdr2),
          _footer(context, ac),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context, AppColors ac) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ac.navy, ac.navy2],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(children: [
        _isGuest
            ? _avatar(ac)
            : InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.of(context).pop(); // close the drawer first
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfilePage(user: user!)));
                },
                child: _avatar(ac),
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isGuest ? 'Guest' : (user!.name.isEmpty ? 'Member' : user!.name),
                style: AppText.title.copyWith(fontSize: 15, color: Colors.white),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(_isGuest
                    ? 'Browsing — sign in for full access'
                    : (user!.classMasterOfClass ?? '').isNotEmpty
                        ? 'Class Master · ${user!.classMasterOfClass}'
                        : user!.isParent ? 'Parent' : user!.roleLabel,
                style: AppText.caption.copyWith(color: Colors.white70),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _avatar(AppColors ac) {
    if (!_isGuest && (user!.photoUrl ?? '').isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundImage: NetworkImage(user!.photoUrl!));
    }
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        shape: BoxShape.circle,
        border: Border.all(color: ac.gold.withValues(alpha: .5)),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
    );
  }

  Widget _item(BuildContext context, AppColors ac, IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: ListTile(
        leading: Icon(icon, color: color ?? ac.txt2, size: 22),
        title: Text(label, style: AppText.subtitle.copyWith(
            fontSize: 14, color: color ?? ac.txt)),
        onTap: () { Navigator.of(context).pop(); onTap(); },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xs)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minLeadingWidth: 28,
      ),
    );
  }

  /// Non-tappable group heading -- "Content" over Library/Past
  /// Questions, "Assessment" over Tests/Quizzes -- visually groups
  /// related items without turning the grouping itself into a route.
  Widget _sectionLabel(AppColors ac, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
      child: Text(title.toUpperCase(), style: AppText.label.copyWith(color: ac.muted, fontSize: 10.5)),
    );
  }

  Widget _footer(BuildContext context, AppColors ac) {
    if (_isGuest) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AccountChoiceScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.gold, foregroundColor: ac.navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
              elevation: 0,
              overlayColor: Colors.black.withValues(alpha: .08),
            ),
            child: Text('Create Free Account',
                style: AppText.button.copyWith(fontSize: 13, color: ac.navy)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListTile(
        leading: Icon(Icons.logout_rounded, color: ac.red, size: 20),
        title: Text('Sign Out', style: AppText.subtitle.copyWith(fontSize: 13, color: ac.red)),
        onTap: () {
          Navigator.of(context).pop();
          AuthService.instance.performSignOut(context);
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xs)),
      ),
    );
  }


  /// Deep-links straight into a Library root folder by name (e.g. "Past
  /// Papers") — falls back to the Academia Library home page if that root
  /// folder was renamed or removed since this shortcut was wired up.
  Future<void> _openLibraryFolderByName(BuildContext context, AppUser user, String name) async {
    final folder = await LibraryFolderRepository.instance.rootFolderByName(name);
    if (!context.mounted) return;
    if (folder == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryHomePage(user: user)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LibraryFolderPage(folderId: folder.id, folderName: folder.name, user: user)));
  }

  void _goSignIn(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LoginScreen(),
    ));
  }
}

