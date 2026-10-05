import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../models/public_course.dart';
import '../repositories/academic_content_repository.dart';
import '../repositories/club_repository.dart';
import '../repositories/messaging_repository.dart';
import '../repositories/public_course_repository.dart';
import '../services/analytics_service.dart';
import '../widgets/widgets.dart';
import '../widgets/app_background.dart';
import '../features/clubs/clubs_page.dart';
import '../features/academic_content/content_details_page.dart';
import '../features/courses_marketplace/course_lessons_page.dart';
import 'profile_page.dart';

class SearchPage extends StatefulWidget {
  final AppUser user;
  const SearchPage({super.key, required this.user});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late TabController _tabController;
  bool _isLoading = false;

  List<AcademicContent> _content = [];
  List<Club> _clubs = [];
  List<Map<String, dynamic>> _users = [];
  List<PublicCourse> _courses = [];
  // Per-tab failure flags — distinguishes "genuinely no results" from
  // "this category's query threw" so a fully-offline search doesn't
  // silently render as four empty tabs.
  bool _contentFailed = false, _clubsFailed = false, _usersFailed = false, _coursesFailed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    // Each category is independent — one failing (e.g. a permission or
    // index error on a single collection) must not blank out the other
    // three tabs. Previously a single rejected Future in Future.wait
    // failed the whole search silently (no catch), leaving every tab
    // stuck showing zero results.
    bool contentFailed = false, clubsFailed = false, usersFailed = false, coursesFailed = false;
    final results = await Future.wait([
      _safe(() => AcademicContentRepository.instance.search(query, institutionId: widget.user.schoolId), <AcademicContent>[], (f) => contentFailed = f),
      _safe(() => ClubRepository.instance.searchClubs(query, user: widget.user), <Club>[], (f) => clubsFailed = f),
      _safe(() => MessagingRepository.instance.searchUsers(query), <Map<String, dynamic>>[], (f) => usersFailed = f),
      _safe(() => PublicCourseRepository.instance.watchLatest().first, <PublicCourse>[], (f) => coursesFailed = f),
    ]);

    setState(() {
      _content = results[0] as List<AcademicContent>;
      _clubs = results[1] as List<Club>;
      _users = results[2] as List<Map<String, dynamic>>;
      _courses = (results[3] as List<PublicCourse>)
          .where((c) => c.title.toLowerCase().contains(query.toLowerCase())).toList();
      _contentFailed = contentFailed;
      _clubsFailed = clubsFailed;
      _usersFailed = usersFailed;
      _coursesFailed = coursesFailed;
      _isLoading = false;
    });
  }

  Future<T> _safe<T>(Future<T> Function() run, T fallback, void Function(bool failed) setFailed) async {
    try {
      final r = await run();
      setFailed(false);
      return r;
    } catch (e, st) {
      CrashService.instance.recordError(e, st, context: 'SearchPage._performSearch');
      setFailed(true);
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.surf,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search...', border: InputBorder.none),
          onSubmitted: _performSearch,
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [Tab(text: 'Library'), Tab(text: 'Groups'), Tab(text: 'People'), Tab(text: 'Courses')],
        ),
      ),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          controller: _tabController,
          children: [
            _buildLibraryList(ac),
            _buildClubList(),
            _buildUserList(),
            _buildCourseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryList(AppColors ac) {
    if (_contentFailed) return ErrorView(message: "Couldn't search the Library — check your connection.", onRetry: () => _performSearch(_ctrl.text));
    if (_ctrl.text.isEmpty) return const EmptyState(icon: Icons.search, title: 'Search the library');
    if (_content.isEmpty) return const EmptyState(icon: Icons.search, title: 'No content found');
    return ListView.builder(
      itemCount: _content.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(_content[i].title),
        subtitle: Text(_content[i].subject),
        leading: Icon(Icons.description, color: ac.primary),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailsPage(user: widget.user, contentId: _content[i].id))),
      ),
    );
  }

  Widget _buildClubList() {
    if (_clubsFailed) return ErrorView(message: "Couldn't search Groups — check your connection.", onRetry: () => _performSearch(_ctrl.text));
    if (_ctrl.text.isEmpty) return const EmptyState(icon: Icons.groups, title: 'Search for groups');
    if (_clubs.isEmpty) return const EmptyState(icon: Icons.groups, title: 'No groups found');
    return ListView.builder(
      itemCount: _clubs.length,
      itemBuilder: (context, i) => ListTile(
        leading: Text(_clubs[i].emoji, style: const TextStyle(fontSize: 24)),
        title: Text(_clubs[i].name),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClubDetailPage(club: _clubs[i], user: widget.user))),
      ),
    );
  }

  Widget _buildUserList() {
    if (_usersFailed) return ErrorView(message: "Couldn't search People — check your connection.", onRetry: () => _performSearch(_ctrl.text));
    if (_ctrl.text.isEmpty) return const EmptyState(icon: Icons.person, title: 'Search for people');
    if (_users.isEmpty) return const EmptyState(icon: Icons.person, title: 'No users found');
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, i) {
        final u = _users[i];
        return ListTile(
          leading: UserAvatar(initials: u['name'][0], photoUrl: u['photo_url'], radius: 18),
          title: Text(u['name']),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: AppUser.fromSupabase(u)))),
        );
      },
    );
  }

  Widget _buildCourseList() {
    if (_coursesFailed) return ErrorView(message: "Couldn't search Courses — check your connection.", onRetry: () => _performSearch(_ctrl.text));
    if (_ctrl.text.isEmpty) return const EmptyState(icon: Icons.school, title: 'Search for courses');
    if (_courses.isEmpty) return const EmptyState(icon: Icons.school, title: 'No courses found');
    return ListView.builder(
      itemCount: _courses.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(_courses[i].title),
        subtitle: Text(_courses[i].creatorName),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseLessonsPage(course: _courses[i], currentUser: widget.user))),
      ),
    );
  }
}