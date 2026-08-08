import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../models/public_course.dart';
import '../repositories/library_repository.dart';
import '../repositories/club_repository.dart';
import '../repositories/messaging_repository.dart';
import '../repositories/public_course_repository.dart';
import '../services/analytics_service.dart';
import '../widgets/widgets.dart';
import '../widgets/app_background.dart';
import '../features/clubs/clubs_page.dart';
import '../features/academic_content/content_details_page.dart';
import '../features/courses_marketplace/course_reader_page.dart';
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

  List<LibraryItem> _content = [];
  List<Club> _clubs = [];
  List<Map<String, dynamic>> _users = [];
  List<PublicCourse> _courses = [];

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
    final results = await Future.wait([
      _safe(() => LibraryRepository.instance.search(query, schoolId: widget.user.schoolId), <LibraryItem>[]),
      _safe(() => ClubRepository.instance.searchClubs(query), <Club>[]),
      _safe(() => MessagingRepository.instance.searchUsers(query), <Map<String, dynamic>>[]),
      _safe(() => PublicCourseRepository.instance.watchLatest().first, <PublicCourse>[]),
    ]);

    setState(() {
      _content = results[0] as List<LibraryItem>;
      _clubs = results[1] as List<Club>;
      _users = results[2] as List<Map<String, dynamic>>;
      _courses = (results[3] as List<PublicCourse>)
          .where((c) => c.title.toLowerCase().contains(query.toLowerCase())).toList();
      _isLoading = false;
    });
  }

  Future<T> _safe<T>(Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } catch (e, st) {
      CrashService.instance.recordError(e, st, context: 'SearchPage._performSearch');
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.surf,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search Academia...', border: InputBorder.none),
          onSubmitted: _performSearch,
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [Tab(text: 'Library'), Tab(text: 'Clubs'), Tab(text: 'People'), Tab(text: 'Courses')],
        ),
      ),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          controller: _tabController,
          children: [
            _buildLibraryList(),
            _buildClubList(),
            _buildUserList(),
            _buildCourseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryList() {
    if (_content.isEmpty) return const EmptyState(icon: Icons.search, title: 'No content found');
    return ListView.builder(
      itemCount: _content.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(_content[i].title),
        subtitle: Text(_content[i].subject),
        leading: const Icon(Icons.description, color: C.primary),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailsPage(user: widget.user, contentId: _content[i].id))),
      ),
    );
  }

  Widget _buildClubList() {
    if (_clubs.isEmpty) return const EmptyState(icon: Icons.groups, title: 'No clubs found');
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
    if (_users.isEmpty) return const EmptyState(icon: Icons.person, title: 'No users found');
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, i) {
        final u = _users[i];
        return ListTile(
          leading: UserAvatar(initials: u['name'][0], photoUrl: u['photoUrl'], radius: 18),
          title: Text(u['name']),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: AppUser.fromFirestore(u['id'], u)))),
        );
      },
    );
  }

  Widget _buildCourseList() {
    if (_courses.isEmpty) return const EmptyState(icon: Icons.school, title: 'No courses found');
    return ListView.builder(
      itemCount: _courses.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(_courses[i].title),
        subtitle: Text(_courses[i].creatorName),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseReaderPage(course: _courses[i], currentUser: widget.user))),
      ),
    );
  }
}