// Repository-driven. Zero static club list.
// Design pass matching the reference layout: header (bell + avatar),
// search + filter row, My Clubs (with Joined/Pending status), Discover
// Clubs (with Approval required/Open to all badges), and cross-promo
// info cards. Backed by a real approval workflow — Club.requiresApproval
// + ClubJoinRequest — that didn't exist before this pass; previously
// every club was instant-join regardless of what the UI implied.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../repositories/club_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../core/result.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../pages/notifications_page.dart';
import '../messages/messages_home_page.dart';
import 'create_club_page.dart';
import 'club_members_page.dart';
import 'club_settings_page.dart';
import 'club_discussion_page.dart';

class ClubsPage extends StatefulWidget {
  final AppUser user;
  const ClubsPage({super.key, required this.user});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  String _searchQuery = '';
  String? _selectedCategory; // null == "All Clubs"
  final _searchCtrl = TextEditingController();

  // Created once and reused across rebuilds -- StreamBuilder resets to its
  // "waiting" state (dropping the whole ListView, including the search bar
  // itself) whenever it's handed a stream with a different identity, and
  // building this inline in `build()` created a brand-new .snapshots()
  // stream on every keystroke's setState. That's what made the Clubs
  // search bar appear to vanish while typing.
  late final Stream<List<Club>> _clubsStream =
      ClubRepository.instance.watchClubs(schoolId: widget.user.schoolId);

  bool get _canCreate => !widget.user.isGuest;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: AppBackground(child: SafeArea(
        child: StreamBuilder<List<Club>>(
          stream: _clubsStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _ClubsSkeleton();
            }
            if (snap.hasError) {
              return ErrorView(message: snap.error.toString());
            }
            final allClubs = snap.data ?? const <Club>[];
            var filtered = _searchQuery.isEmpty
                ? allClubs
                : allClubs.where((c) =>
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    c.category.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
            if (_selectedCategory != null) {
              filtered = filtered.where((c) => c.category == _selectedCategory).toList();
            }
            final categories = allClubs.map((c) => c.category).toSet().toList()..sort();

            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _header(context),
                const SizedBox(height: 10),
                _searchAndFilter(),
                if (categories.length > 1) ...[
                  const SizedBox(height: 12),
                  _categoryChips(categories),
                ],
                const SizedBox(height: 20),
                // production_plan.md §7B — "Contextual recommendations should
                // exist throughout Academia." Only shown in the unfiltered
                // view, same "don't stack a recommendation rail on top of a
                // search/filter the user is already doing" gate every other
                // surface's rail uses (Library/Courses/Past Papers).
                if (_searchQuery.isEmpty && _selectedCategory == null) ...[
                  _recommendedClubsSection(context, allClubs),
                ],
                _myClubsSection(context, filtered),
                const SizedBox(height: 24),
                _discoverClubsSection(context, filtered, allClubs),
                const SizedBox(height: 20),
                _infoCards(context),
              ],
            );
          },
        ),
      )),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              backgroundColor: ac.navy,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateClubPage(user: widget.user)));
              },
              icon: Icon(Icons.add_rounded, color: ac.gold),
              label: Text('Create Club', style: AppText.button.copyWith(fontSize: 13)),
            )
          : null,
    );
  }

  Widget _header(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clubs', style: AppText.h1.copyWith(fontSize: 22)),
            Text('Find your people. Share ideas. Grow together.', style: AppText.caption.copyWith(fontSize: 12)),
          ]),
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: widget.user.id))),
        ),
        UserAvatar(initials: widget.user.name.isEmpty ? '?' : widget.user.name[0].toUpperCase(),
            radius: 18, photoUrl: widget.user.photoUrl),
      ]),
    );
  }

  Widget _searchAndFilter() {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.bdr)),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppText.bodySm.copyWith(color: ac.txt),
              decoration: InputDecoration(
                hintText: 'Search clubs by name, interest or subject…',
                hintStyle: AppText.bodySm.copyWith(color: ac.muted, fontSize: 12.5),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: ac.muted),
                border: InputBorder.none, isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.bdr)),
          child: Row(children: [
            Icon(Icons.filter_list_rounded, size: 18, color: ac.txt2),
            const SizedBox(width: 6),
            Text('Filter', style: AppText.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  /// "All Clubs" + every real category currently in use, driven by
  /// actual Club.category values (not a hardcoded list) — matches the
  /// mockup's chip row without inventing categories no club actually has.
  Widget _categoryChips(List<String> categories) {
    final ac = AppColors.of(context);
    final chips = ['All Clubs', ...categories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = chips[i];
          final isAll = label == 'All Clubs';
          final active = isAll ? _selectedCategory == null : _selectedCategory == label;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = isAll ? null : label);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? ac.navy : ac.surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? ac.navy : ac.bdr),
                ),
                child: Text(label, style: AppText.caption.copyWith(
                    fontSize: 12.5, fontWeight: FontWeight.w700,
                    color: active ? ac.gold : ac.txt2)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _myClubsSection(BuildContext context, List<Club> allClubs) {
    if (widget.user.isGuest) return const SizedBox.shrink();
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('My Clubs', style: AppText.h2.copyWith(fontSize: 16))),
          Text('View all', style: AppText.subtitle.copyWith(color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        if (allClubs.isEmpty)
          Text('No clubs yet — discover one below or create your own.', style: AppText.bodySm)
        else
          Container(
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
            child: Column(children: [
              for (int i = 0; i < allClubs.length; i++)
                _MyClubTile(
                  club: allClubs[i], user: widget.user,
                  showDivider: i < allClubs.length - 1,
                  onOpen: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ClubDetailPage(club: allClubs[i], user: widget.user))),
                ),
            ]),
          ),
      ]),
    );
  }

  /// production_plan.md §7B — "Contextual recommendations should exist
  /// throughout Academia," replacing the removed Clubs banner. Ranks the
  /// club list this page already streamed (`allClubs`) against the
  /// signed-in user's favorite subjects via
  /// RecommendationRepository.forClubs -- no second Firestore read, same
  /// "hide entirely rather than show an empty personalized rail"
  /// treatment as every other surface's recommendation rail.
  Widget _recommendedClubsSection(BuildContext context, List<Club> allClubs) {
    if (widget.user.isGuest || widget.user.favoriteSubjects.isEmpty) {
      return const SizedBox.shrink();
    }
    final recommended = RecommendationRepository.instance
        .forClubs(pool: allClubs, favoriteSubjects: widget.user.favoriteSubjects);
    if (recommended.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recommended for You', style: AppText.h2.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommended.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _DiscoverClubCard(
              club: recommended[i], user: widget.user,
              onOpen: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ClubDetailPage(club: recommended[i], user: widget.user))),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _discoverClubsSection(BuildContext context, List<Club> allClubs, List<Club> unfilteredClubs) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Discover Clubs', style: AppText.h2.copyWith(fontSize: 16))),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.xs),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AllClubsPage(clubs: unfilteredClubs, user: widget.user))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('See all', style: AppText.subtitle.copyWith(
                    color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (allClubs.isEmpty)
          Text('No clubs on Academia yet — be the first to create one.', style: AppText.bodySm)
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allClubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _DiscoverClubCard(
                club: allClubs[i], user: widget.user,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDetailPage(club: allClubs[i], user: widget.user))),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _infoCards(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.groups_rounded, color: ac.blu, size: 20),
              const SizedBox(height: 8),
              Text('Clubs', style: AppText.title.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Shared spaces around common interests. Join open clubs or request to join those that require approval.',
                  style: AppText.caption.copyWith(fontSize: 10.5, height: 1.35)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.chat_bubble_rounded, color: ac.pur, size: 20),
              const SizedBox(height: 8),
              Text('Messages', style: AppText.title.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('One-to-one connections. Follow anyone or send a friend request to start a conversation.',
                  style: AppText.caption.copyWith(fontSize: 10.5, height: 1.35)),
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.user.isGuest) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesHomePage(user: widget.user)));
                  },
                  child: Text('Go to Messages →', style: AppText.caption.copyWith(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.pur)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ClubsSkeleton extends StatelessWidget {
  const _ClubsSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const ShimmerLine(width: 100, height: 24),
        const SizedBox(height: 20),
        for (int i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(children: [
              ShimmerCircle(size: 44),
              SizedBox(width: 12),
              Expanded(child: ShimmerLine(height: 14)),
            ]),
          ),
      ],
    );
  }
}

/// A row in "My Clubs" — only rendered if the current user is actually a
/// member or has a pending join request; resolves its own status live so
/// the list updates the moment a request is approved.
class _MyClubTile extends StatelessWidget {
  final Club club;
  final AppUser user;
  final bool showDivider;
  final VoidCallback onOpen;
  const _MyClubTile({required this.club, required this.user, required this.showDivider, required this.onOpen});

  List<Color> _palette(AppColors ac) => [ac.gold, ac.blu, ac.grn, ac.pur, ac.org];
  Color _accent(AppColors ac) {
    final p = _palette(ac);
    return p[club.name.hashCode.abs() % p.length];
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(club.id, user.id),
      builder: (context, roleSnap) {
        final role = roleSnap.data ?? ClubRole.visitor;
        if (role != ClubRole.visitor) {
          return _tile(context, statusLabel: 'Joined', statusColor: ac.grn, statusBg: ac.grnBg);
        }
        return StreamBuilder<ClubJoinRequestStatus?>(
          stream: ClubRepository.instance.watchMyRequestStatus(club.id, user.id),
          builder: (context, reqSnap) {
            if (reqSnap.hasError) {
              // Embedded status badge inside a fixed-height tile row — an
              // ErrorView here would break the row's layout, so this just
              // records the failure and falls back to "no badge" (same as
              // the loading/absent state) rather than a silent empty look
              // masking a real query failure.
              CrashService.instance.recordError(reqSnap.error, reqSnap.stackTrace,
                  context: 'ClubsPage.watchMyRequestStatus(${club.id}, ${user.id})');
              return const SizedBox.shrink();
            }
            if (reqSnap.data != ClubJoinRequestStatus.pending) return const SizedBox.shrink();
            return _tile(context, statusLabel: 'Pending', statusColor: ac.org, statusBg: ac.orgBg, disabled: true);
          },
        );
      },
    );
  }

  Widget _tile(BuildContext context, {required String statusLabel, required Color statusColor, required Color statusBg, bool disabled = false}) {
    final ac = AppColors.of(context);
    final accent = _accent(ac);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : () { HapticFeedback.selectionClick(); onOpen(); },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: ac.bdr2))) : null,
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(club.emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(club.name, style: AppText.title.copyWith(fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(statusLabel, style: AppText.label.copyWith(fontSize: 9.5, color: statusColor, letterSpacing: 0)),
                  ),
                ]),
                Text(club.description, style: AppText.bodySm.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Icon(Icons.people_alt_outlined, size: 12, color: ac.muted),
                  const SizedBox(width: 3),
                  Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
                ]),
              ]),
            ),
            if (!disabled) Icon(Icons.chevron_right_rounded, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}

/// Discover card — join instantly if open, or request-to-join if the
/// club requires approval. Hides itself once the user is already a
/// member or has a pending request (those show up in My Clubs instead).
class _DiscoverClubCard extends StatelessWidget {
  final Club club;
  final AppUser user;
  final VoidCallback onOpen;
  final bool fullWidth;
  const _DiscoverClubCard({required this.club, required this.user, required this.onOpen, this.fullWidth = false});

  List<Color> _palette(AppColors ac) => [ac.pur, ac.org, ac.grn, ac.blu, ac.gold];
  Color _accent(AppColors ac) {
    final p = _palette(ac);
    return p[club.name.hashCode.abs() % p.length];
  }

  Widget _emojiTile(AppColors ac) => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: _accent(ac).withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
        child: Center(child: Text(club.emoji, style: const TextStyle(fontSize: 18))),
      );

  @override
  Widget build(BuildContext context) {
    if (user.isGuest) return _card(context, joined: false, pending: false);
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(club.id, user.id),
      builder: (context, roleSnap) {
        final isMember = (roleSnap.data ?? ClubRole.visitor) != ClubRole.visitor;
        if (isMember) return const SizedBox.shrink();
        return StreamBuilder<ClubJoinRequestStatus?>(
          stream: ClubRepository.instance.watchMyRequestStatus(club.id, user.id),
          builder: (context, reqSnap) {
            if (reqSnap.hasError) {
              // Same reasoning as _MyClubTile above: this only gates
              // whether the join card still shows, so record the failure
              // and fall back to showing the card rather than an ErrorView
              // wedged into a horizontally-scrolling card list.
              CrashService.instance.recordError(reqSnap.error, reqSnap.stackTrace,
                  context: 'ClubsPage.watchMyRequestStatus(${club.id}, ${user.id})');
              return _card(context, joined: false, pending: false);
            }
            final pending = reqSnap.data == ClubJoinRequestStatus.pending;
            if (pending) return const SizedBox.shrink();
            return _card(context, joined: false, pending: false);
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, {required bool joined, required bool pending}) {
    final ac = AppColors.of(context);
    final hasCover = (club.bannerUrl ?? '').isNotEmpty;
    return Container(
      width: fullWidth ? double.infinity : 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasCover)
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(club.bannerUrl!, height: 84, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _emojiTile(ac)),
          )
        else
          _emojiTile(ac),
        const SizedBox(height: 10),
        Text(club.name, style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          Icon(club.requiresApproval ? Icons.lock_outline_rounded : Icons.public_rounded,
              size: 12, color: club.requiresApproval ? ac.pur : ac.grn),
          const SizedBox(width: 4),
          Text(club.requiresApproval ? 'Approval required' : 'Open to all',
              style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: club.requiresApproval ? ac.pur : ac.grn)),
        ]),
        const SizedBox(height: 6),
        // Expanded only makes sense inside the horizontal preview's fixed-
        // height card; the vertical "See all" list has no bounded height
        // to expand into, so it just wraps the text directly there.
        if (fullWidth)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(club.description, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          )
        else
          Expanded(
            child: Text(club.description, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        Row(children: [
          Icon(Icons.people_alt_outlined, size: 12, color: ac.muted),
          const SizedBox(width: 3),
          Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _handleJoin(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.navy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(club.requiresApproval ? 'Request to Join' : 'Join Club',
                style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Future<void> _handleJoin(BuildContext context) async {
    if (user.isGuest) {
      showToast(context, 'Create an account to join clubs');
      return;
    }
    HapticFeedback.mediumImpact();
    if (club.requiresApproval) {
      final result = await ClubRepository.instance.requestToJoin(
        clubId: club.id, clubName: club.name,
        userId: user.id, userName: user.name, userPhotoUrl: user.photoUrl,
      );
      if (context.mounted) {
        showToast(context, result is Success ? 'Request sent — pending admin approval.' : (result as Failure).message);
      }
    } else {
      final result = await ClubRepository.instance.joinClub(
        club.id, user.id, name: user.name, photoUrl: user.photoUrl,
      );
      if (context.mounted) {
        showToast(context, result is Success ? '✅ Welcome to ${club.name}!' : 'Failed to join');
      }
    }
  }
}

/// Full scrollable list behind Discover Clubs' "See all" -- the homepage
/// section only shows a horizontally-scrolling preview of every club, so
/// this is the same data in an actually-scannable vertical list rather
/// than a real paginated fetch (there's nothing more to page in; the
/// preview already held every club).
class AllClubsPage extends StatelessWidget {
  final List<Club> clubs;
  final AppUser user;
  const AllClubsPage({super.key, required this.clubs, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Discover Clubs', style: AppText.title),
      ),
      body: AppBackground(child: clubs.isEmpty
          ? const EmptyState(icon: Icons.groups_outlined, title: 'No clubs on Academia yet',
              subtitle: 'Be the first to create one.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: clubs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _DiscoverClubCard(
                club: clubs[i], user: user, fullWidth: true,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDetailPage(club: clubs[i], user: user))),
              ),
            )),
    );
  }
}

// ── Club Detail Page ──────────────────────────────────────
class ClubDetailPage extends StatefulWidget {
  final Club club;
  final AppUser user;
  const ClubDetailPage({super.key, required this.club, required this.user});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  static const _chatTabIndex = 2;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  /// Marks the club Chat read the moment the tab actually becomes
  /// visible — mirrors ChatConversationPage calling markConversationRead
  /// in initState, just gated on tab selection here since ClubDetailPage
  /// hosts five other tabs a member might open without ever seeing Chat.
  void _onTabChanged() {
    if (_tabs.indexIsChanging) return; // fires again on settle; act once
    if (_tabs.index == _chatTabIndex) {
      ClubRepository.instance.markClubRead(widget.club.id, widget.user.id);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final msg = ClubMessage(
      id: '',
      senderId: widget.user.id,
      senderName: widget.user.name,
      senderInitials: widget.user.initials,
      text: text,
      time: DateTime.now(),
    );
    _ctrl.clear();
    await ClubRepository.instance.sendMessage(widget.club.id, msg);
    await Future.delayed(const Duration(milliseconds: 80));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Custom club banners were fully wired up on the create flow (image
    // picker -> Storage upload -> Club.bannerUrl) but nothing ever
    // rendered them -- every club looked identical regardless of what
    // was uploaded. Shows as a tinted header behind the title when set;
    // falls back to the plain AppBar exactly as before when it isn't.
    final ac = AppColors.of(context);
    final hasBanner = (widget.club.bannerUrl ?? '').isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: hasBanner ? 96 : kToolbarHeight,
        flexibleSpace: hasBanner
            ? Stack(fit: StackFit.expand, children: [
                Image.network(widget.club.bannerUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: ac.navy)),
                Container(decoration: const BoxDecoration(gradient: LinearGradient(
                    colors: [Color(0xB3000000), Color(0x33000000)],
                    begin: Alignment.bottomCenter, end: Alignment.topCenter))),
              ])
            : null,
        title: Row(children: [
          Text(widget.club.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.club.name,
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700,
                    color: hasBanner ? Colors.white : null)),
            Text('${widget.club.memberCount} members',
                style: TextStyle(fontSize: 11, color: hasBanner ? Colors.white70 : ac.muted)),
          ]),
        ]),
        iconTheme: hasBanner ? const IconThemeData(color: Colors.white) : null,
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [
          Tab(text: 'FEED'), Tab(text: 'DISCUSSIONS'), Tab(text: 'CHAT'), Tab(text: 'MEMBERS'),
          Tab(text: 'RESOURCES'), Tab(text: 'EVENTS')]),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Invite members',
            onPressed: () {
              HapticFeedback.selectionClick();
              Share.share(
                  '${widget.club.emoji} Join "${widget.club.name}" on Academia!\n\n'
                  '${widget.club.description}\n\n'
                  'Open the Academia app, go to Clubs, and search for it to join.');
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Members',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ClubMembersPage(club: widget.club, currentUser: widget.user))),
          ),
          StreamBuilder<ClubRole>(
            stream: ClubRepository.instance.watchUserRole(widget.club.id, widget.user.id),
            builder: (context, snap) {
              if (snap.data != ClubRole.admin) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Club settings',
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubSettingsPage(club: widget.club, currentUser: widget.user))),
              );
            },
          ),
        ],
      ),
      body: TabBarView(controller: _tabs, children: [
        _FeedTab(club: widget.club, user: widget.user),
        _DiscussionsTab(club: widget.club, user: widget.user),
        _ChatTab(club: widget.club, user: widget.user,
            scroll: _scroll, ctrl: _ctrl, onSend: _send),
        ClubMembersBody(club: widget.club, currentUser: widget.user),
        _ResourcesTab(club: widget.club, user: widget.user),
        _EventsTab(club: widget.club, user: widget.user),
      ]),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  final ScrollController scroll;
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _ChatTab({required this.club, required this.user,
    required this.scroll, required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(children: [
      Expanded(
        child: StreamBuilder<List<ClubMessage>>(
          stream: ClubRepository.instance.watchMessages(club.id),
          builder: (context, snap) {
            final messagesList = snap.data ?? [];
            return ListView.builder(
              controller: scroll, padding: const EdgeInsets.all(16),
              itemCount: messagesList.length,
              itemBuilder: (_, i) {
                final m = messagesList[i];
                final isMe = m.senderId == user.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe)
                        Container(
                            width: 28, height: 28,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                                color: ac.goldBg, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text(m.senderInitials,
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700, color: ac.gold)))),
                      Flexible(child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(padding: const EdgeInsets.only(left: 2, bottom: 2),
                                child: Text(m.senderName,
                                    style: TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w600, color: ac.muted))),
                          GestureDetector(
                            onLongPress: (isMe && !m.deleted) ? () => _confirmDelete(context, m) : null,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * .65),
                                decoration: BoxDecoration(
                                  color: m.deleted ? ac.surf3 : (isMe ? ac.primary : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: (isMe && !m.deleted) ? null : Border.all(color: ac.bdr),
                                ),
                                child: Text(m.deleted ? 'This message was deleted' : m.text,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: m.deleted ? FontStyle.italic : FontStyle.normal,
                                        color: m.deleted ? ac.muted : (isMe ? Colors.white : ac.txt)))),
                          ),
                          Padding(padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                  '${m.time.hour.toString().padLeft(2, '0')}:'
                                      '${m.time.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 9, color: ac.muted))),
                        ],
                      )),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
        decoration: BoxDecoration(
            color: ac.surf, border: Border(top: BorderSide(color: ac.bdr))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: ctrl,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                      hintText: 'Message ${club.name}…',
                      filled: true, fillColor: ac.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: ac.bdr)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: ac.bdr)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10)))),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                onSend();
              },
              child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: ac.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 18)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context, ClubMessage m) async {
    final ac = AppColors.of(context);
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will replace it with "This message was deleted" for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: ac.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ClubRepository.instance.deleteMessage(club.id, m.id, user.id);
    }
  }
}

/// The club's Feed — real posts (clubs/{id}/posts), replacing the old
/// static "no announcements yet" placeholder. Admins/moderators can flag
/// a post as an Announcement (pinned styling, matches the mockup's
/// "Physics Competition — Registration Open!" card); regular members can
/// post too.
class _FeedTab extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _FeedTab({required this.club, required this.user});

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: StreamBuilder<List<ClubPost>>(
        stream: ClubRepository.instance.watchPosts(widget.club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final posts = snap.data ?? const <ClubPost>[];
          if (posts.isEmpty) {
            return const EmptyState(icon: Icons.campaign_outlined, title: 'No posts yet',
                subtitle: 'Be the first to post something for this club.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _PostCard(club: widget.club, user: widget.user, post: posts[i]),
          );
        },
      ),
      floatingActionButton: widget.user.isGuest ? null : FloatingActionButton(
        backgroundColor: ac.navy,
        onPressed: () => _composePost(context),
        child: Icon(Icons.edit_rounded, color: ac.gold, size: 20),
      ),
    );
  }

  void _composePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ComposePostSheet(club: widget.club, user: widget.user),
    );
  }
}

class _ComposePostSheet extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _ComposePostSheet({required this.club, required this.user});

  @override
  State<_ComposePostSheet> createState() => _ComposePostSheetState();
}

class _ComposePostSheetState extends State<_ComposePostSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _announcement = false;
  bool _posting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      showToast(context, 'Add a title and some text first.');
      return;
    }
    setState(() => _posting = true);
    final result = await ClubRepository.instance.createPost(widget.club.id, ClubPost(
      id: '', clubId: widget.club.id, authorId: widget.user.id, authorName: widget.user.name,
      authorPhotoUrl: widget.user.photoUrl, isAnnouncement: _announcement,
      title: title, body: body, createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _posting = false);
    if (result is Success) {
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(widget.club.id, widget.user.id),
      builder: (context, roleSnap) {
        final canAnnounce = roleSnap.data == ClubRole.admin || roleSnap.data == ClubRole.moderator;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New Post', style: AppText.title.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              TextField(controller: _titleCtrl,
                  decoration: const InputDecoration(hintText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _bodyCtrl, minLines: 3, maxLines: 6,
                  decoration: const InputDecoration(hintText: "What's on your mind?", border: OutlineInputBorder())),
              if (canAnnounce)
                CheckboxListTile(
                  value: _announcement, onChanged: (v) => setState(() => _announcement = v ?? false),
                  title: const Text('Post as Announcement'), contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _posting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: _posting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Post'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final Club club;
  final AppUser user;
  final ClubPost post;
  const _PostCard({required this.club, required this.user, required this.post});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(initials: post.authorName.isEmpty ? '?' : post.authorName[0].toUpperCase(),
              radius: 16, photoUrl: post.authorPhotoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.authorName, style: AppText.title.copyWith(fontSize: 13)),
              Text(_relativeTime(post.createdAt), style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
          ),
          if (post.isAnnouncement)
            StatusBadge(label: 'ANNOUNCEMENT', color: ac.gold),
        ]),
        const SizedBox(height: 10),
        Text(post.title, style: AppText.title.copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text(post.body, style: AppText.bodySm.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          _LikeChip(club: club, post: post, user: user),
          const SizedBox(width: 16),
          Icon(Icons.mode_comment_outlined, size: 16, color: ac.muted),
          const SizedBox(width: 4),
          Text('${post.commentCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
        ]),
      ]),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _LikeChip extends StatelessWidget {
  final Club club;
  final ClubPost post;
  final AppUser user;
  const _LikeChip({required this.club, required this.post, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (user.isGuest) {
      return Row(children: [
        Icon(Icons.favorite_border_rounded, size: 16, color: ac.muted),
        const SizedBox(width: 4),
        Text('${post.likeCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
      ]);
    }
    return StreamBuilder<bool>(
      stream: ClubRepository.instance.watchIsPostLiked(club.id, post.id, user.id),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: () {
              HapticFeedback.lightImpact();
              ClubRepository.instance.togglePostLike(club.id, post.id, user.id);
            },
            child: Row(children: [
              Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 16, color: liked ? ac.red : ac.muted),
              const SizedBox(width: 4),
              Text('${post.likeCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
            ]),
          ),
        );
      },
    );
  }
}

/// The club's Discussions tab — Q&A threads with a mark-able best answer
/// and XP rewards. Matches the Physics Society mockup's second screen.
class _DiscussionsTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _DiscussionsTab({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: StreamBuilder<List<ClubDiscussion>>(
        stream: ClubRepository.instance.watchDiscussions(club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final discussions = snap.data ?? const <ClubDiscussion>[];
          if (discussions.isEmpty) {
            return const EmptyState(icon: Icons.forum_outlined, title: 'No discussions yet',
                subtitle: 'Ask a question and earn XP when your answer helps someone.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: discussions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = discussions[i];
              return _DiscussionCard(
                discussion: d,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDiscussionDetailPage(club: club, user: user, discussion: d))),
              );
            },
          );
        },
      ),
      floatingActionButton: user.isGuest ? null : FloatingActionButton.extended(
        backgroundColor: ac.navy,
        icon: Icon(Icons.add_rounded, color: ac.gold),
        label: Text('Ask', style: AppText.button.copyWith(fontSize: 13)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AskQuestionPage(club: club, user: user))),
      ),
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  final ClubDiscussion discussion;
  final VoidCallback onOpen;
  const _DiscussionCard({required this.discussion, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UserAvatar(initials: discussion.authorName.isEmpty ? '?' : discussion.authorName[0].toUpperCase(),
                  radius: 14, photoUrl: discussion.authorPhotoUrl),
              const SizedBox(width: 8),
              Expanded(child: Text(discussion.authorName, style: AppText.bodySm.copyWith(fontSize: 12))),
              if (discussion.bestAnswerReplyId != null)
                Icon(Icons.check_circle_rounded, color: ac.grn, size: 16),
            ]),
            const SizedBox(height: 8),
            Text(discussion.title, style: AppText.title.copyWith(fontSize: 14.5)),
            if ((discussion.tag ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              StatusBadge(label: discussion.tag!, color: ac.pur),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.mode_comment_outlined, size: 14, color: ac.muted),
              const SizedBox(width: 4),
              Text('${discussion.replyCount}', style: AppText.caption.copyWith(fontSize: 11)),
              const SizedBox(width: 12),
              Icon(Icons.visibility_outlined, size: 14, color: ac.muted),
              const SizedBox(width: 4),
              Text('${discussion.viewCount}', style: AppText.caption.copyWith(fontSize: 11)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Shared links/files — matches the mockup's RESOURCES tab. Any signed-in
/// member can add one; the uploader or club staff can remove it.
class _ResourcesTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _ResourcesTab({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: StreamBuilder<List<ClubResource>>(
        stream: ClubRepository.instance.watchResources(club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 300));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final resources = snap.data ?? const <ClubResource>[];
          if (resources.isEmpty) {
            return const EmptyState(icon: Icons.folder_open_outlined, title: 'No resources yet',
                subtitle: 'Share a link or file useful to the whole club.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: resources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = resources[i];
              final canRemove = r.uploaderId == user.id;
              return ACard(
                onTap: () {
                  final uri = Uri.tryParse(r.url);
                  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(r.isFile ? Icons.insert_drive_file_outlined : Icons.link_rounded, color: ac.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, style: AppText.title.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Shared by ${r.uploaderName}', style: AppText.caption.copyWith(fontSize: 11)),
                    ]),
                  ),
                  if (canRemove)
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: ac.muted),
                      onPressed: () => ClubRepository.instance.deleteResource(club.id, r.id),
                    ),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: user.isGuest ? null : FloatingActionButton(
        backgroundColor: ac.navy,
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _AddResourceSheet(club: club, user: user),
        ),
        child: Icon(Icons.add_rounded, color: ac.gold),
      ),
    );
  }
}

class _AddResourceSheet extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _AddResourceSheet({required this.club, required this.user});

  @override
  State<_AddResourceSheet> createState() => _AddResourceSheetState();
}

class _AddResourceSheetState extends State<_AddResourceSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (title.isEmpty || url.isEmpty) {
      showToast(context, 'Add a title and a link.');
      return;
    }
    setState(() => _saving = true);
    final result = await ClubRepository.instance.addResource(widget.club.id, ClubResource(
      id: '', clubId: widget.club.id, title: title, url: url,
      uploaderId: widget.user.id, uploaderName: widget.user.name, uploaderPhotoUrl: widget.user.photoUrl,
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Share a Resource', style: AppText.title.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(hintText: 'Link (https://…)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Share'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Upcoming club events with lightweight RSVP — matches the mockup's
/// EVENTS tab.
class _EventsTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _EventsTab({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: StreamBuilder<List<ClubEvent>>(
        stream: ClubRepository.instance.watchEvents(club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 300));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final events = (snap.data ?? const <ClubEvent>[])
              .where((e) => e.startAt.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();
          if (events.isEmpty) {
            return const EmptyState(icon: Icons.event_outlined, title: 'No upcoming events',
                subtitle: 'Plan something for the club to look forward to.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _EventCard(club: club, event: events[i], user: user),
          );
        },
      ),
      floatingActionButton: user.isGuest ? null : FloatingActionButton(
        backgroundColor: ac.navy,
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _AddEventSheet(club: club, user: user),
        ),
        child: Icon(Icons.add_rounded, color: ac.gold),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Club club;
  final ClubEvent event;
  final AppUser user;
  const _EventCard({required this.club, required this.event, required this.user});

  String _fmt(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day} · $h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.title, style: AppText.title.copyWith(fontSize: 14.5)),
        const SizedBox(height: 4),
        Text(_fmt(event.startAt), style: AppText.bodySm.copyWith(fontSize: 12, color: ac.primary)),
        if ((event.location ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.place_outlined, size: 13, color: ac.muted),
            const SizedBox(width: 3),
            Text(event.location!, style: AppText.caption.copyWith(fontSize: 11)),
          ]),
        ],
        if ((event.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(event.description!, style: AppText.bodySm.copyWith(fontSize: 12.5)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Text('${event.rsvpCount} going', style: AppText.caption.copyWith(fontSize: 11)),
          const Spacer(),
          if (!user.isGuest)
            StreamBuilder<bool>(
              stream: ClubRepository.instance.watchIsGoingToEvent(club.id, event.id, user.id),
              builder: (context, snap) {
                final going = snap.data ?? false;
                return OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ClubRepository.instance.toggleEventRsvp(club.id, event.id, user.id, !going);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: going ? ac.grnBg : null,
                    side: BorderSide(color: going ? ac.grn : ac.bdr),
                  ),
                  child: Text(going ? 'Going ✓' : 'RSVP', style: AppText.caption.copyWith(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: going ? ac.grn : ac.txt2)),
                );
              },
            ),
        ]),
      ]),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _AddEventSheet({required this.club, required this.user});

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Give the event a title.');
      return;
    }
    setState(() => _saving = true);
    final startAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final result = await ClubRepository.instance.addEvent(widget.club.id, ClubEvent(
      id: '', clubId: widget.club.id, title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      startAt: startAt, location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      creatorId: widget.user.id, creatorName: widget.user.name,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Event', style: AppText.title.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Event title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                      context: context, initialDate: _date,
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _date = picked);
                },
                child: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
                child: Text(_time.format(context)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _locationCtrl, decoration: const InputDecoration(hintText: 'Location (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _descCtrl, minLines: 2, maxLines: 4,
              decoration: const InputDecoration(hintText: 'Description (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Event'),
            ),
          ),
        ]),
      ),
    );
  }
}