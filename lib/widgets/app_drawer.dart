// lib/widgets/app_drawer.dart
// Global navigation drawer — Courses, Past Questions, Clubs, Magazine,
// Messages, Profile, Settings, Notifications, Help, and (superAdmin only)
// Admin Panel. Shared by the universal dashboard for every account type.
//
// Guest (user == null) can open every destination to browse, but write
// actions inside those destinations should independently refuse Guests —
// this drawer only controls navigation, not the read/write gate itself.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../models/institution.dart';
import '../services/auth_service.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../features/admin/admin_panel_page.dart';
import '../features/onboarding/account_choice_screen.dart';
import '../screens/login_screen.dart';
import '../models/school_config.dart';
import '../features/courses_marketplace/courses_marketplace_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/academic_content/academic_content_page.dart';
import '../features/messages/messages_home_page.dart';
import '../models/academic_content.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../pages/notifications_page.dart';
import '../pages/help_support_page.dart';
import '../features/testing/tests_subject_picker_page.dart';
import '../features/testing/grading_page.dart';

class AppDrawer extends StatelessWidget {
  final AppUser? user;
  final Institution? institution;
  const AppDrawer({super.key, this.user, this.institution});

  bool get _isGuest => user == null;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: C.surf,
      child: SafeArea(
        child: Column(children: [
          _header(context),
          const Divider(height: 1, color: C.bdr2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              children: [
                _item(context, Icons.home_rounded, 'Home', () {}),
                _item(context, Icons.school_rounded, 'Courses', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CoursesMarketplacePage(user: user)));
                }),
                _item(context, Icons.folder_copy_rounded, 'Content Library', () {
                  if (_isGuest) {
                    _goSignIn(context);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AcademicContentPage(user: user!)));
                  }
                }),
                _item(context, Icons.description_rounded, 'Past Questions', () {
                  if (_isGuest) {
                    _goSignIn(context);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AcademicContentPage(
                            user: user!, initialTypeFilter: ContentType.pastPaper)));
                  }
                }),
                _item(context, Icons.groups_rounded, 'Clubs', () {
                  if (_isGuest) {
                    _goSignIn(context);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ClubsPage(user: user!)));
                  }
                }),
                _item(context, Icons.menu_book_rounded, 'Magazine', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MagazineFeedPage(user: user)));
                }),
                _item(context, Icons.quiz_rounded, 'Tests & Quizzes', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TestsSubjectPickerPage(user: user ?? AppUser.guest())));
                }),
                _item(context, Icons.chat_bubble_outline_rounded, 'Messages', () {
                  if (_isGuest) {
                    _goSignIn(context);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MessagesHomePage(user: user!)));
                  }
                }),
                const Divider(height: 24, thickness: 1, indent: 16, endIndent: 16, color: C.bdr2),
                _item(context, Icons.person_outline_rounded, 'Profile', () {
                  if (_isGuest) {
                    _goSignIn(context);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProfilePage(user: user!, institution: institution)));
                  }
                }),
                _item(context, Icons.settings_outlined, 'Settings', () {
                  if (_isGuest) {
                    _goSignIn(context);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SettingsPage(user: user!)));
                  }
                }),
                _item(context, Icons.notifications_outlined, 'Notifications', () {
                  if (_isGuest) {
                    _goSignIn(context);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NotificationsPage(userId: user!.id)));
                  }
                }),
                _item(context, Icons.help_outline_rounded, 'Help & Support',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const HelpSupportPage()))),
                if (!_isGuest && user!.hasMinRole(UserRole.lecturer)) ...[
                  const Divider(height: 24, thickness: 1, indent: 16, endIndent: 16, color: C.bdr2),
                  _item(context, Icons.rate_review_rounded, 'Grading Queue', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GradingPage(grader: user!)));
                  }),
                ],
                if (!_isGuest && user!.canManagePlatform) ...[
                  const Divider(height: 24, thickness: 1, indent: 16, endIndent: 16, color: C.bdr2),
                  _item(context, Icons.admin_panel_settings_rounded, 'Admin Panel', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AdminPanelPage(user: user!)));
                  }, color: C.gold),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: C.bdr2),
          _footer(context),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [C.navy, C.navy2],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(children: [
        _isGuest
            ? _avatar()
            : InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.of(context).pop(); // close the drawer first
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfilePage(user: user!, institution: institution)));
                },
                child: _avatar(),
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isGuest ? 'Guest' : (user!.name.isEmpty ? 'Member' : user!.name),
                style: AppText.title.copyWith(fontSize: 15, color: Colors.white),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(_isGuest ? 'Browsing — sign in for full access' : user!.roleLabel,
                style: AppText.caption.copyWith(color: Colors.white70),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _avatar() {
    if (!_isGuest && (user!.photoUrl ?? '').isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundImage: NetworkImage(user!.photoUrl!));
    }
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        shape: BoxShape.circle,
        border: Border.all(color: C.gold.withValues(alpha: .5)),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: ListTile(
        leading: Icon(icon, color: color ?? C.txt2, size: 22),
        title: Text(label, style: AppText.subtitle.copyWith(
            fontSize: 14, color: color ?? C.txt)),
        onTap: () { Navigator.of(context).pop(); onTap(); },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xs)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minLeadingWidth: 28,
      ),
    );
  }

  Widget _footer(BuildContext context) {
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
              backgroundColor: C.gold, foregroundColor: C.navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
              elevation: 0,
              overlayColor: Colors.black.withValues(alpha: .08),
            ),
            child: Text('Create Free Account',
                style: AppText.button.copyWith(fontSize: 13, color: C.navy)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: C.red, size: 20),
        title: Text('Sign Out', style: AppText.subtitle.copyWith(fontSize: 13, color: C.red)),
        onTap: () {
          Navigator.of(context).pop();
          AuthService.instance.signOut();
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xs)),
      ),
    );
  }


  void _goSignIn(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LoginScreen(school: SchoolConfig(
        id: 'independent', name: 'Academia',
        motto: 'Sign in to your account', academicYear: '',
      )),
    ));
  }
}

